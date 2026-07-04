# Full-install CI + heavy-package opt-in gating

## Problem

The existing CI (`.github/workflows/test-dotfiles.yml`) is a smoke test, not a
real install test, and it let several real bugs through:

- `test-windows` only runs `chezmoi init --apply --dry-run` — dry-run never
  executes scripts, so it can't catch exec-time bugs (e.g. the Windows
  `%1 is not a valid Win32 application` class of bug).
- `test-macos` runs a real `chezmoi init --apply`, but then manually runs
  `brew install fish jq tmux ...` itself rather than letting the real
  `run_onchange_after_00-install-brews.sh.tmpl` script do it (brewfile.tmpl
  skips heavy packages whenever `$CI` is set).
- `test-ubuntu` does a real bootstrap, but installs chezmoi to a CI-chosen
  PATH-friendly location, masking PATH-resolution bugs a real user could hit
  (e.g. `chezmoi: command not found` when chezmoi lives somewhere else).

Separately, `packages/brewfile.tmpl` and `packages/scoopfile` install some
genuinely heavy toolchains (llvm, nodejs, golang, ghcup, rustup) unconditionally
on any non-container machine. These are slow (some build from source) and not
always wanted immediately after a fresh dotfiles apply.

## Goals

1. Add CI jobs that do a real, undiluted `chezmoi init --apply` on Ubuntu,
   macOS, and Windows, gated to run only after the existing smoke tests pass.
2. Gate `llvm`, `nodejs`, `golang`, `ghcup`, and `rustup` behind an explicit
   opt-in flag, separate from container/CI detection. `pixi` remains
   always-installed.

## Design

### 1. Decouple "container" from "CI" (`packages/brewfile.tmpl`)

`$is_container` currently is `true` when `/.dockerenv` exists **or** `$CI` is
set. GitHub Actions always sets `CI=true`, so there's no way to distinguish
"really in a container" from "any CI job." Split these:

- `$is_container` becomes purely `(stat "/.dockerenv")` — true containers only
  (cuda-dev, local `docker run` tests) get it automatically.
- New explicit opt-in env var `HOMEBREW_SKIP_HEAVY` controls the existing
  lightweight subset (awscli, bats-core, cmake, coreutils, git-flow, gnupg,
  htop, juliaup, llm, openjdk, pandoc, roborev). The existing smoke-test CI
  jobs (`test-ubuntu`, `test-macos`) set this explicitly to keep their current
  fast behavior unchanged.

### 2. New `DOTFILES_FULL_INSTALL` opt-in flag

chezmoi doesn't support custom CLI flags on `init`/`apply`, so the flag is an
environment variable, consistent with the repo's existing `CI`/`GITHUB_ACTIONS`
gating convention:

```sh
DOTFILES_FULL_INSTALL=1 chezmoi apply          # Linux/macOS
```
```powershell
$env:DOTFILES_FULL_INSTALL = "1"; chezmoi init --apply jesserobertson   # Windows
```

Effects, independent of container/CI status:

- `packages/brewfile.tmpl`: `pixi` moves out of the heavy block into the
  always-install cross-platform section. `llvm`, `nodejs`, `golang`, `ghcup`
  move out of the container-gated heavy block into a new
  `{{ if $full_install }}` block.
- `packages/scoopfile`: `nodejs`, `rustup`, `ghcup`, `go` move to a new
  `packages/scoopfile.full`. `run_onchange_windows_install-packages.ps1.tmpl`
  installs from it only `{{ if env "DOTFILES_FULL_INSTALL" }}`.
- `.chezmoiignore.tmpl`: `01-install-rust.fish` (rustup isn't a brew formula —
  `scripts/install-rust.fish` installs it via `curl https://sh.rustup.rs`) is
  skipped entirely unless `DOTFILES_FULL_INSTALL` is set.

macOS GUI casks (raycast, chromium, anki, etc.) are handled separately by the
user and out of scope here — the full-install CI job does not attempt them.

### 3. New CI jobs in `test-dotfiles.yml`

Three new jobs, each gated with `needs:` on its matching smoke-test job only
(not all three — a Windows smoke failure shouldn't block the Linux
full-install from starting):

- `full-install-ubuntu` (`needs: [test-ubuntu]`): install chezmoi via the same
  `get.chezmoi.io` one-liner the README documents, then
  `chezmoi init --source="$GITHUB_WORKSPACE" --apply` (real apply, no
  `--dry-run`, no `--exclude=scripts`), with `DOTFILES_FULL_INSTALL=1` set and
  `HOMEBREW_SKIP_HEAVY` unset, then `tests/verify-installation.sh`.
- `full-install-macos` (`needs: [test-macos]`): same shape, macOS runner.
- `full-install-windows` (`needs: [test-windows]`): `winget install
  twpayne.chezmoi`, then `chezmoi init --source="$env:GITHUB_WORKSPACE"
  --apply` (real, not dry-run), then a new inline verification step checking
  `chezmoi status` is empty and spot-checking key scoop/cargo tools
  (`starship`, `zoxide`, `fzf`, `ripgrep`, `fd`, `bat`, `delta`, `yq`, `helix`,
  `gh`, `aws`) are on `PATH`.

All three use `--source="$GITHUB_WORKSPACE"` (the checked-out commit), not a
fresh GitHub clone, since what matters is testing the code as committed in
this run.

Trigger: same `on:` block as the rest of the workflow (push to main, pull
request, workflow_dispatch) — `needs:` gating applies uniformly regardless of
which event triggered the run.

`timeout-minutes: 20` on each new job.

### 4. README

Document the `DOTFILES_FULL_INSTALL` flag and what it enables.

## Out of scope

- macOS GUI cask installation in CI (handled separately by the user).
- Cargo crate installation (`scripts/install-crates.*`) is unaffected — it
  already skips whenever plain `$CI` is set, independent of this design.
