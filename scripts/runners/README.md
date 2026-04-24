# Runner host scripts

- **`validate-host-prereqs.sh`** — Run on a self-hosted builder **before** registering it with GitHub Actions. See **`docs/runner-image-requirements.md`** for the full checklist (sudoers, disk, `gh`, private repo access, etc.).

These scripts complement `.github/workflows/*.yml`; they do not install Xcode, Visual Studio, or Android SDKs end-to-end.
