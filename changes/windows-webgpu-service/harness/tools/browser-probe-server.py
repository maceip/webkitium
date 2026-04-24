#!/usr/bin/env python3
"""Tiny harness server: bind 127.0.0.1:<port>, accept one POST to /, write the
body to <out>, then exit. Used by the webgpu-browser-probe CI workflow to
capture JSON from validate-probe.html without scraping the live DOM.

Exits 0 on report received, 2 on timeout, 3 on misuse.
"""
from __future__ import annotations

import argparse
import http.server
import pathlib
import sys
import threading

class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "webgpu-probe-harness/1.0"

    def log_message(self, fmt, *args):
        # Route access log to stderr with a consistent prefix.
        sys.stderr.write("[harness] " + (fmt % args) + "\n")

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        # Serve the probe page same-origin so fetch() to POST / doesn't hit
        # a cross-scheme block (file:// -> http://127.0.0.1 is blocked by
        # default in many browsers).
        import os
        html_path = getattr(self.server, "html_path", None)
        if html_path and os.path.isfile(html_path):
            with open(html_path, "rb") as f:
                body = f.read()
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self._cors()
        self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length) if length > 0 else b""
        out = self.server.out_path  # type: ignore[attr-defined]
        try:
            out.write_bytes(body)
        except OSError as e:
            self.send_response(500)
            self._cors()
            self.end_headers()
            self.wfile.write(str(e).encode("utf-8", "replace"))
            return
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true,"bytes":%d}' % len(body))
        print(f"[harness] received {len(body)} bytes -> {out}", flush=True)
        # Tell the server thread to stop, then the main thread to exit.
        self.server.received = True  # type: ignore[attr-defined]
        threading.Thread(target=self.server.shutdown, daemon=True).start()

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8787)
    ap.add_argument("--out", default="report.json")
    ap.add_argument("--timeout", type=int, default=60)
    ap.add_argument("--html", default="", help="Serve this HTML on GET /")
    args = ap.parse_args()

    out_path = pathlib.Path(args.out).resolve()
    html_path = str(pathlib.Path(args.html).resolve()) if args.html else None
    if not (0 < args.port < 65536):
        print("invalid --port", file=sys.stderr)
        return 3

    server = http.server.HTTPServer(("127.0.0.1", args.port), Handler)
    server.out_path = out_path  # type: ignore[attr-defined]
    server.html_path = html_path  # type: ignore[attr-defined]
    server.received = False  # type: ignore[attr-defined]
    print(f"[harness] listening on http://127.0.0.1:{args.port}/  "
          f"(timeout {args.timeout}s)", flush=True)

    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    t.join(timeout=args.timeout)

    if server.received:  # type: ignore[attr-defined]
        return 0
    server.shutdown()
    print(f"[harness] timed out after {args.timeout}s waiting for report",
          file=sys.stderr)
    return 2

if __name__ == "__main__":
    sys.exit(main())
