---
name: Patch failure or wrong tree
about: Patch did not apply, `.rej` files, or uncertainty whether work belongs in `changes/<lane>/` vs `patches/<platform>/`.
title: "[patch] "
labels: patch
---

## Platform / lane

(e.g. `windows`, `android`, `changes/windows-webgpu-service`)

## Patch path(s) in this repo

## Expected behavior

## What happened

Paste the **smallest** relevant excerpt: `git apply` output, compiler error, or `.rej` context.

## Build id (optional)

Runner build id or S3 log link if this came from CI.

## Where you think it should live

- [ ] `patches/<platform>/` (always-on platform plumbing)
- [ ] `changes/<lane>/patches/` (toggleable lane — check `config/changes.json`)

See [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) for the split.
