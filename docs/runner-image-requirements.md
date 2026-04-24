# Self-hosted runner image requirements

GitHub Actions workflows in this repo assume a **persistent builder VM or AMI**, not a clean GitHub-hosted runner. The YAML exercises the tree and calls `sudo`, `gh`, Xcode, and GTK installers where needed; **image configuration** must satisfy the items below or jobs will fail in ways YAML cannot fix.

## Cross-cutting

| Requirement | Why | Image / ops fix |
|-------------|-----|-------------------|
| **Disk** | WebKit + NDK + ccache fills tens to hundreds of GB. | Root volume or data volume sized for worst platform; monitor `df`. |
| **`git`** | Checkout, patch apply, pin verification. | Package manager or Xcode CLT (macOS). |
| **`gh` CLI** | `webkit-pin` release download. | `brew install gh` / package install; see **GitHub auth** below. |
| **Non-interactive `sudo`** | macOS Metal download, Linux `install-dependencies`. | `sudoers.d` rule for the runner user: **NOPASSWD** for the exact commands you allow (see examples below), or bake deps into the image and avoid `sudo` in CI. |
| **Private repo checkout** | `actions/checkout` uses `GITHUB_TOKEN` from the job; the **runner account** must be allowed to read the repo if the token is insufficient. | Org “Actions” access for forks; PAT in repo secrets + `token:` on checkout; or runner as org member with repo read. |
| **Long job timeouts** | WebKit builds exceed default hosted limits. | Self-hosted labels only; workflow `timeout-minutes` already high. |

## GitHub CLI (`gh`) auth

Workflows run `gh release download …` with `GITHUB_TOKEN` injected by Actions for that job. That works when:

- The default token can read **releases** (including **draft** releases if you use drafts for `webkit-pin` — then `permissions: contents: write` or equivalent is required in the workflow, as in this repo), and  
- The runner process actually receives that token (normal for `runs-on: self-hosted` with `actions/checkout`).

If `gh release download` fails with **403** or **not found**:

1. Confirm the **`webkit-pin`** release exists and tag name matches `config/webkit-build-matrix.json` → `webkit.pinReleaseTag`.  
2. For draft assets, ensure workflow **`permissions.contents`** is sufficient.  
3. As a fallback, bake **`GH_TOKEN`** / **`GITHUB_TOKEN`** into the runner env (not ideal) or use a **fine-grained PAT** in repo secrets and `env: GH_TOKEN: ${{ secrets.… }}` on the step (document in org runbook).

Optional smoke test on the machine (after a human login once):

```bash
gh auth status
```

## macOS (`macos-build`, `ios-build`)

| Requirement | Notes |
|-------------|--------|
| **Xcode / SDKs** | iOS simulator builds need appropriate Xcode; `xcodebuild -license accept` may run in CI (already in workflow). Prefer **image with Xcode pre-installed** to avoid long first-boot. |
| **Metal toolchain** | Workflow may run `sudo xcodebuild -downloadComponent MetalToolchain`. Requires **passwordless sudo** for that command or pre-install Metal support on the AMI. |
| **`/opt/homebrew` or `/usr/local`** | `gh`, `cmake`, `ninja`, etc. on `PATH` as used in workflows. |

Example **sudoers fragment** (tighten paths to your Xcode.app):

```text
# /etc/sudoers.d/github-runner-webkitium
runneruser ALL=(root) NOPASSWD: /usr/bin/xcodebuild
```

## Linux ARM64 (`android-build`, `linux-gtk-build`)

| Requirement | Notes |
|-------------|--------|
| **Android SDK + NDK** | Expected layout under `$HOME/Android/Sdk` (or set `ANDROID_HOME`). NDK **prebuilt** must match host (**aarch64** vs x86_64); workflows detect `linux-aarch64` vs `linux-x86_64`. |
| **Java / Gradle** | WPE-Android uses `./gradlew`. |
| **GTK deps** | `linux-gtk-build` may run `Tools/gtk/install-dependencies` with `sudo`. Either **pre-bake packages** into the AMI or grant **NOPASSWD** for that script path only. |
| **`ubuntu` vs other user** | Some scripts assume home paths; keep the Actions runner user consistent with AMI layout. |

Example sudoers (replace user and path after first image bake):

```text
githubrunner ALL=(root) NOPASSWD: /home/githubrunner/webkit-src-gtk/Tools/gtk/install-dependencies
```

Prefer **Dockerfile / cloud-init / Ansible** that runs `install-dependencies` once at image build time so CI never calls `sudo`.

## Windows (`windows-build`, `windows-runner-check`)

| Requirement | Notes |
|-------------|--------|
| **Visual Studio Build Tools, LLVM, CMake, Ninja, Perl, Ruby, Python** | Paths in `windows-build.yml` and `windows-runner-check.yml` must exist on the AMI (`C:\BuildTools\…`, `C:\Program Files\LLVM\…`, etc.). |
| **`vcpkg`** | Fixed root `C:\vcpkg` and triplet **`x64-windows-webkit`** as in workflow; registry baseline must match `config/webkit-build-matrix.json` / `config/vcpkg-configuration.json`. |
| **`gh`** | GitHub CLI on PATH for bash prepare steps. Same auth considerations as Linux/macOS. |

Bake **LiteRT-LM** clone + `git lfs pull` into the image if you want to avoid network on every run (workflow still clones if missing).

## Validation script

Run **`scripts/runners/validate-host-prereqs.sh`** on a new VM before registering it as a self-hosted runner. It checks disk, `git`, `gh`, and optional non-interactive `sudo`. It does **not** replace image baking; it catches obvious gaps early.

## Relation to repo config

Pins and flags live in **`config/webkit-build-matrix.json`** and related files under **`config/`**. The **image** supplies tooling versions and permissions; the **repo** supplies the exact WebKit/Dawn matrix those workflows enforce.
