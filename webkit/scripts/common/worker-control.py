#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


def utc():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def write_json(path, obj):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, separators=(",", ":"), ensure_ascii=True), encoding="utf-8")


class Worker:
    def __init__(self, args):
        self.args = args
        self.workdir = Path(args.workdir)
        self.bundle = Path(args.bundle_root)
        self.artifacts = self.workdir / "artifacts"
        self.status_path = self.workdir / "status.json"
        self.heartbeat_path = self.workdir / "heartbeat.json"
        self.cancel_path = self.workdir / "CANCEL_REQUESTED.txt"
        self.cancelled_path = self.workdir / "BUILD_CANCELLED.txt"
        self.failed_path = self.workdir / "BUILD_FAILED.txt"
        self.done_path = self.workdir / "BUILD_DONE.txt"
        self.ready_path = self.workdir / "BUILD_READY.txt"
        self.output_log = self.workdir / "worker-output.log"

    def status(self, status, stage, **details):
        obj = {
            "schema": 1,
            "platform": self.args.platform,
            "status": status,
            "stage": stage,
            "updated": utc(),
            "pid": os.getpid(),
            "details": details or None,
        }
        write_json(self.status_path, obj)
        write_json(self.heartbeat_path, {k: obj[k] for k in ("schema", "platform", "status", "stage", "updated", "pid")})

    def cache(self, state, reason, **details):
        write_json(self.workdir / "cache-state.json", {
            "schema": 1,
            "state": state,
            "reason": reason,
            "updated": utc(),
            "details": details or None,
        })

    def cancelled(self):
        return self.cancel_path.exists()

    def mark_cancelled(self, stage):
        message = f"cancelled by orchestrator during {stage} at {utc()}"
        self.cancelled_path.write_text(message, encoding="utf-8")
        self.status("cancelled", stage, reason=message)
        return 130

    def classify_cache(self):
        config_path = self.bundle / "build-config.json"
        if not config_path.exists():
            self.cache("unknown", "build-config.json missing")
            return
        cfg = json.loads(config_path.read_text(encoding="utf-8"))
        source = Path(cfg.get("cleanSourceRoot") or cfg.get("legacySourceRoot") or "")
        build_dir = source / "WebKitBuild" if source else None
        preserve = bool(cfg.get("preserveBuildDir"))
        if not build_dir or not build_dir.exists():
            self.cache("cold", "no existing WebKitBuild")
        elif preserve:
            self.cache("preserve-requested", "remote-build.ps1 will validate launcher compatibility", buildDir=str(build_dir))
        else:
            self.cache("cleaning", "preserveBuildDir=false", buildDir=str(build_dir))

    def run_remote_build(self):
        remote = self.bundle / "remote-build.ps1"
        if not remote.exists():
            raise RuntimeError(f"remote-build.ps1 missing at {remote}")
        cmd = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(remote)]
        with self.output_log.open("ab") as log:
            proc = subprocess.Popen(cmd, cwd=str(self.workdir), stdout=log, stderr=subprocess.STDOUT)
            while proc.poll() is None:
                self.publish_progress()
                if self.cancelled():
                    self.status("cancelling", "remote-build", childPid=proc.pid)
                    proc.terminate()
                    try:
                        proc.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                    raise KeyboardInterrupt("cancel requested")
                time.sleep(10)
            self.publish_progress()
            if proc.returncode:
                raise RuntimeError(f"remote-build.ps1 exited with code {proc.returncode}")

    def publish_progress(self):
        progress = self.artifacts / "build-progress.json"
        detail = {}
        if progress.exists():
            try:
                detail["progress"] = json.loads(progress.read_text(encoding="utf-8"))
            except Exception:
                detail["progressPath"] = str(progress)
        self.status("running", detail.get("progress", {}).get("backend") or "remote-build", **detail)

    def artifact_validity(self):
        required = ["patch-manifest.json", "manifest-pre.json", "manifest-post.json", "validation-report.json"]
        files = {name: (self.artifacts / name).exists() for name in required}
        files["releaseTarball"] = any(self.artifacts.glob("webkitium-windows-*.tar.gz"))
        valid = all(files.values())
        report = {"schema": 1, "valid": valid, "files": files, "s3Prefix": self.args.s3_prefix, "updated": utc()}
        write_json(self.workdir / "artifact-validity.json", report)
        if not valid:
            raise RuntimeError("artifact validity failed; see artifact-validity.json")

    def copy_control_files(self):
        for name in ("status.json", "heartbeat.json", "cache-state.json", "artifact-validity.json"):
            src = self.workdir / name
            if src.exists() and self.artifacts.exists():
                shutil.copy2(src, self.artifacts / name)

    def upload_artifacts(self):
        if not self.artifacts.exists():
            return
        self.status("running", "artifact-upload")
        cmd = [
            self.args.aws_exe, "s3", "sync", str(self.artifacts), self.args.s3_prefix,
            "--exclude", "*", "--include", "*.zip", "--include", "*.tar.gz",
            "--include", "*.json", "--include", "*.log", "--include", "*.html",
        ]
        subprocess.check_call(cmd)

    def run(self):
        self.workdir.mkdir(parents=True, exist_ok=True)
        self.status("running", "worker-start")
        self.classify_cache()
        try:
            if self.cancelled():
                return self.mark_cancelled("worker-start")
            self.status("running", "remote-build")
            self.run_remote_build()
            self.ready_path.write_text(f"remote-build complete {utc()}\n", encoding="utf-8")
            self.status("running", "artifact-validate")
            self.artifact_validity()
            self.copy_control_files()
            self.upload_artifacts()
            self.status("succeeded", "done", s3Prefix=self.args.s3_prefix)
            self.done_path.write_text(f"success {utc()} uploaded={self.args.s3_prefix}\n", encoding="utf-8")
            return 0
        except KeyboardInterrupt:
            return self.mark_cancelled("remote-build")
        except Exception as exc:
            self.status("failed", "failed", error=str(exc))
            if self.artifacts.exists():
                try:
                    self.copy_control_files()
                    self.upload_artifacts()
                except Exception:
                    pass
            self.failed_path.write_text(f"{exc}\n", encoding="utf-8")
            return 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True)
    parser.add_argument("--workdir", required=True)
    parser.add_argument("--bundle-root", required=True)
    parser.add_argument("--s3-prefix", required=True)
    parser.add_argument("--aws-exe", required=True)
    return Worker(parser.parse_args()).run()


if __name__ == "__main__":
    sys.exit(main())
