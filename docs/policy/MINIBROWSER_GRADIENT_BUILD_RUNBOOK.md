# MiniBrowser Gradient Build Runbook

Purpose: candidate command sequence for producing one Windows WebKit MiniBrowser
build with the gradient chrome and app icon change.

This is written as an operator checklist, not as proof that a green gradient
artifact already exists. The working assumption is:

```text
MiniBrowser gradient/icon patch.
Previously successful Windows build profile.
Runner API for build control and status.
One active build at a time.
```

## 1. Confirm no build is running

```bash
cd /home/cory/Webkitium

curl -sS http://127.0.0.1:8787/builds > /tmp/webkitium-builds.json

node <<'NODE'
const fs = require('fs');
const builds = JSON.parse(fs.readFileSync('/tmp/webkitium-builds.json', 'utf8'));
const running = builds.filter(b => b.status === 'running');

if (running.length) {
  console.log('RUNNING BUILDS:');
  for (const b of running)
    console.log(`${b.id}\t${b.reason}`);
  process.exit(1);
}

console.log('No running builds.');
NODE
```

If any build is running, cancel only through the orchestrator:

```bash
curl -sS -X POST http://127.0.0.1:8787/builds/<build-id>/cancel
```

Use the orchestrator API for build control and status.

## 2. Verify the patch touches only MiniBrowser paint/icon files

```bash
cd /home/cory/Webkitium

grep -E '^diff --git ' \
  webkit/patches/windows/0034-windows-minibrowser-webkitium-toolbar-gradient.patch \
  | sed 's/^diff --git a\///; s/ b\/.*//'
```

Expected output:

```text
Tools/MiniBrowser/win/CMakeLists.txt
Tools/MiniBrowser/win/MainWindow.cpp
Tools/MiniBrowser/win/MainWindow.h
Tools/MiniBrowser/win/mini_appicon.ico
```

If the file list differs, return to patch verification before launching a build.

## 3. Verify the patch clean-applies to the pinned WebKit source

Use the local validation worktree only:

```bash
cd /home/cory/Webkitium

git -C /tmp/webkit-52dbebe-check reset --hard
git -C /tmp/webkit-52dbebe-check clean -fd

git -C /tmp/webkit-52dbebe-check apply --check \
  /home/cory/Webkitium/webkit/patches/windows/0034-windows-minibrowser-webkitium-toolbar-gradient.patch
```

If `apply --check` fails, resolve patch validity before launching a build.

## 4. Apply locally and re-check the changed file list

```bash
git -C /tmp/webkit-52dbebe-check apply \
  /home/cory/Webkitium/webkit/patches/windows/0034-windows-minibrowser-webkitium-toolbar-gradient.patch

git -C /tmp/webkit-52dbebe-check diff --name-only
```

Expected output:

```text
Tools/MiniBrowser/win/CMakeLists.txt
Tools/MiniBrowser/win/MainWindow.cpp
Tools/MiniBrowser/win/MainWindow.h
Tools/MiniBrowser/win/mini_appicon.ico
```

If the file list differs, return to patch verification before launching a build.

## 5. Inspect the source hunks for compile hazards

```bash
git -C /tmp/webkit-52dbebe-check diff -- \
  Tools/MiniBrowser/win/CMakeLists.txt \
  Tools/MiniBrowser/win/MainWindow.cpp \
  Tools/MiniBrowser/win/MainWindow.h \
  | sed -n '1,280p'
```

Search for scope drift indicators:

```bash
git -C /tmp/webkit-52dbebe-check diff -- \
  Tools/MiniBrowser/win/CMakeLists.txt \
  Tools/MiniBrowser/win/MainWindow.cpp \
  Tools/MiniBrowser/win/MainWindow.h \
  | rg -n "TODO|<<<<<<<|>>>>>>>|ENABLE_WEBGPU|GPU_PROCESS|Source/WebKit|Source/WebCore|remote|WebGPU|Dawn"
```

Expected: no output.

Search for obvious Windows compile hazards:

```bash
git -C /tmp/webkit-52dbebe-check diff -- \
  Tools/MiniBrowser/win/MainWindow.cpp \
  Tools/MiniBrowser/win/MainWindow.h \
  | rg -n "GradientFill|PathAppend|LoadImage|WM_CTLCOLOR|NM_CUSTOMDRAW|HBRUSH|HICON|pragma comment|msimg32|shlwapi"
```

Manually confirm any new Win32 API has the required include/library support in
the same MiniBrowser patch. If it requires a new system library, that belongs in
`Tools/MiniBrowser/win/CMakeLists.txt`, not WebKit core.

## 6. Verify the binary icon patch

```bash
test -f /tmp/webkit-52dbebe-check/Tools/MiniBrowser/win/mini_appicon.ico
file /tmp/webkit-52dbebe-check/Tools/MiniBrowser/win/mini_appicon.ico
```

Expected: a Windows icon resource. If the file is missing or corrupt, resolve the icon patch before launching a build.

## 7. Confirm the requested lane does not override WebGPU/GPU process

Use this only when the selected baseline explicitly includes it:

```text
NG_WINDOWS_ENABLE_WEBGPU=0
```

Use the MiniBrowser gradient preset and provide only the patch filter unless the selected baseline explicitly documents additional environment values.

## 8. Start exactly one Windows build

```bash
cd /home/cory/Webkitium

curl -sS -X POST http://127.0.0.1:8787/builds \
  -H 'content-type: application/json' \
  -d '{
    "platforms": ["windows"],
    "reason": "windows minibrowser gradient marketing build - paint only known lane",
    "presets": {
      "windows": "minibrowser-gradient-retry"
    },
    "platformEnv": {
      "windows": {
        "NG_WINDOWS_ROOT_PATCH_FILTER": "0034-windows-minibrowser-webkitium-toolbar-gradient.patch,0091-windows-minibrowser-bmalloc-fix.patch,0092-windows-minibrowser-wtf-fix.patch"
      }
    }
  }'
```

Record the returned id:

```bash
BUILD_ID=<returned-id>
```

Start the next build after the current build has finished or has been cancelled through the orchestrator.

## 9. Monitor through the orchestrator only

```bash
BUILD_ID=<returned-id>

curl -sS "http://127.0.0.1:8787/builds/$BUILD_ID"

curl -sS "http://127.0.0.1:8787/builds/$BUILD_ID/logs/windows?tail=80"
```

Repeat status polling:

```bash
watch -n 30 "curl -sS 'http://127.0.0.1:8787/builds/$BUILD_ID/logs/windows?tail=25' | tail -n 25"
```

Use the orchestrator API for monitoring.

## 10. If the build fails

Collect the first actionable error before relaunching.

Fetch the uploaded build log:

```bash
BUILD_ID=<build-id>

mkdir -p "/home/cory/.local/state/webkitium/artifacts/$BUILD_ID"

aws s3 cp \
  "s3://cory-build-artifacts-euc1-095713295645-20260407/webkitium/windows/$BUILD_ID/build-webkit-$BUILD_ID.log" \
  "/home/cory/.local/state/webkitium/artifacts/$BUILD_ID/build.log"

tail -n 260 "/home/cory/.local/state/webkitium/artifacts/$BUILD_ID/build.log"
```

Classify the first actionable error.

If the first actionable error is in one of these files, review the gradient patch:

```text
Tools/MiniBrowser/win/CMakeLists.txt
Tools/MiniBrowser/win/MainWindow.cpp
Tools/MiniBrowser/win/MainWindow.h
Tools/MiniBrowser/win/mini_appicon.ico
```

Fix only those files, then restart from step 2.

If the first actionable error is outside those files, review the selected lane, baseline, or cache state:

```text
Source/WebKit/...
Source/WebCore/...
Source/cmake/...
Tools/Scripts/...
```

Keep MiniBrowser patch changes separate from lane, baseline, or cache remediation.

## 11. If the build succeeds

Get artifact metadata:

```bash
BUILD_ID=<successful-id>

curl -sS "http://127.0.0.1:8787/builds/$BUILD_ID/artifacts"
```

List outputs:

```bash
aws s3 ls \
  "s3://cory-build-artifacts-euc1-095713295645-20260407/webkitium/windows/$BUILD_ID/" \
  --recursive
```

Download outputs:

```bash
mkdir -p "/home/cory/.local/state/webkitium/artifacts/$BUILD_ID/downloads"

aws s3 sync \
  "s3://cory-build-artifacts-euc1-095713295645-20260407/webkitium/windows/$BUILD_ID/" \
  "/home/cory/.local/state/webkitium/artifacts/$BUILD_ID/downloads/"
```

Find the package/MiniBrowser executable:

```bash
find "/home/cory/.local/state/webkitium/artifacts/$BUILD_ID/downloads" \
  -iname '*MiniBrowser*' -o -iname '*.zip' -o -iname '*.7z' -o -iname '*.exe'
```

## Scope checklist

- Patch edits stay in `Tools/MiniBrowser/win/` for this gradient build.
- Environment overrides match the selected baseline.
- Runner API remains the source of build status and logs.
- One Windows build is active at a time.
- First-error extraction happens before another launch.
