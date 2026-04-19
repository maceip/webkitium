# Build status

Rotating log of recent builds. **Canonical artifact paths** and bucket layout: [`ASSETS.md`](./ASSETS.md).

## Latest (newest first)

| When (UTC)          | Platform       | Build id                                   | Result    | Notes |
| ------------------- | -------------- | ------------------------------------------ | --------- | ----- |
| 2026-04-16 02:26    | Windows+WebGPU | `dawn-d3d12-runtime-20260416T011849Z`      | ✅ **green** | 33m 55s compile, artifact uploaded, `webgpu_dawn.dll` load fixed with matching Abseil DLL |
| 2026-04-15 15:16    | macOS          | `macos-clean-20260415T151654Z`             | ❌ failed  | libwebrtc `network_constants.h` -Wconstant-conversion under Xcode 16, fix in flight |
| 2026-04-15 14:54    | Windows+WebGPU | `dawn-iovalidator-20260415T145405Z`        | ✅ **green** | 33m 29s, all 9551 targets, `ENABLE_WEBGPU=ON`, tar in S3 |
| 2026-04-15 14:54    | macOS          | `macos-parallel-20260415T145430Z`          | ❌ failed  | (other agent) concurrent build collision with mine |
| 2026-04-15 13:45    | Windows+WebGPU | `dawn-wgsl-20260415T134548Z`               | ❌ failed  | WGSL generator compile error, fixed in patch 0006 |
| 2026-04-15 13:25    | Windows+WebGPU | `dawn-webgpu-20260415T132500Z`             | ❌ failed  | WGSL generator 3-args bug, fixed in patch 0005 |
| 2026-04-15 12:51    | macOS          | `macos-20260415T125117Z`                   | ❌ failed  | libwebrtc boringssl rename error (concurrency with parallel build) |
| 2026-04-15 12:47    | macOS          | `macos-first-20260415T124714Z`             | ❌ failed  | `nohup + disown` didn't survive SSM session; replaced with `launchctl submit` |
| 2026-04-15 12:27    | Windows+WebGPU | `dawn-webgpu-windows-20260415T122728Z`     | ⚠️  partial | Compiled 33m 23s but `ENABLE_WEBGPU=OFF` — PRIVATE flag overrode `-D`, fixed in patch 0004 |
| 2026-04-15 11:08    | Windows        | `fix-stderr2-20260415T110839Z`             | ✅ green   | Baseline (no WebGPU), 33m 23s, tar in S3 |
| 2026-04-15 09:05    | Windows        | `green-20260415T090558Z`                   | ❌ failed  | Worker died silently — AwsExe path with spaces broke `Start-Process -ArgumentList` |
| 2026-04-14 05:09    | Android        | `20260414T050928-81903`                    | ✅ green   | Local gradle build, APKs + AAR + runtime tarballs in S3 |

Runner notes and API: [`RUNNER.md`](./RUNNER.md). Automation policy: [`BUILD_AUTOMATION.md`](./BUILD_AUTOMATION.md). Windows host: [`../../webkit/scripts/windows/WINDOWS_BUILDER.md`](../../webkit/scripts/windows/WINDOWS_BUILDER.md).

## Example download (Windows + WebGPU)

```bash
aws s3 cp s3://cory-build-artifacts-euc1-095713295645-20260407/ng-webkit/windows/dawn-d3d12-runtime-20260416T011849Z/ng-webkit-windows-dawn-d3d12-runtime-20260416T011849Z.tar.gz \
  . --region eu-central-1
```

See [`ASSETS.md`](./ASSETS.md) for presigned URLs and full catalog.
