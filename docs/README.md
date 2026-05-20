# Documentation index

**Naming:** **Webkitium** = this repository. **WebKit NG** = the browser product.

| Order | Doc | Purpose |
|-------|-----|---------|
| 1 | [`README.md`](../README.md) | Scope, roles, targets, run a build |
| 2 | [`ARCHITECTURE.md`](ARCHITECTURE.md) | Directory roles, patch tree, build flow |
| 2b | [`DIRECTION.md`](DIRECTION.md) | Guiding light, phases, guardrails |
| 2c | [`ENGINE_EMBED.md`](ENGINE_EMBED.md) | **Chrome must use pinned engine** (policy + env) |
| 2d | [`CHROME_PLATFORM_REVIEW.md`](CHROME_PLATFORM_REVIEW.md) | Per-platform wiring + CI honesty |
| 2e | [`MINIBROWSER_GAPS.md`](MINIBROWSER_GAPS.md) | Feature gaps vs MiniBrowser baseline |
| 3 | [`policy/STATUS.md`](policy/STATUS.md) | Recent build outcomes |
| 4 | [`policy/RUNNER.md`](policy/RUNNER.md), [`../orchestrator/RUNNER_API.md`](../orchestrator/RUNNER_API.md), [`policy/ASSETS.md`](policy/ASSETS.md) | Runner, API, S3 |
| 5 | [`WEBGPU_PROGRAM.md`](WEBGPU_PROGRAM.md) | Windows WebGPU milestones |
| 5b | [`WEBNN_PROGRAM.md`](WEBNN_PROGRAM.md) | WebNN inference milestones |
| 6 | [`policy/DOCUMENTATION.md`](policy/DOCUMENTATION.md) | Redirect / entry |

**Chrome:** [`../chrome/README.md`](../chrome/README.md) and per-OS `chrome/<platform>/README.md`.

**Historical audit (do not follow for builds):** [`../AGENT_AUDIT.md`](../AGENT_AUDIT.md).

Lane docs: `changes/<lane>/` and `docs/windows-webgpu-service/`, `docs/webnn-service/`.
