# Agent Instructions

Personal dotfiles managed with [chezmoi](https://chezmoi.io). Supports macOS, Linux (via Homebrew), and Windows.

## Repository structure

```
.chezmoi.toml.tmpl          # Single source of truth for all template variables
dot_bashrc.tmpl             # Bash config (renders to ~/.bashrc)
dot_zshrc.tmpl              # Zsh config (renders to ~/.zshrc)
dot_config/fish/            # Fish config
dot_config/powershell/      # PowerShell config (Windows)
dot_config/shell/env.sh.tmpl # Shared POSIX env vars (sourced by bash/zsh via chezmoi)
packages/                   # brewfile.tmpl, wingetfile, scoopfile, cratefile, etc.
scripts/                    # install-prereqs.sh, install-brew.sh, install-crates.ps1, etc.
tests/                      # bats tests (tests/bats/), Docker bootstrap tests, Pester (Windows)
```

## Setup is two steps, not one

`chezmoi apply` only lays down dotfiles. Tool installation is separate:

```sh
make bootstrap   # full setup: dotfiles + prereqs + brew + rust + crates + ...
```

Tests mirror this: `test-bootstrap.sh` runs both `chezmoi init --apply` and then the install scripts explicitly.

## Template variables

All template data lives in `.chezmoi.toml.tmpl`. Key variables:
- `.editor` — default shell editor (currently `hx` / helix)
- `.homebrew_prefix` — `/opt/homebrew` (macOS arm64), `/usr/local` (macOS x86), `/home/linuxbrew/.linuxbrew` (Linux)
- `.ssh_auth_sock` — 1Password agent path; **empty string on Linux** so always guard with `{{- if .ssh_auth_sock }}`
- `.cargo_home` — `~/.local/share/cargo` (not `~/.cargo`)
- `.xdg_*` — XDG base dirs baked in at render time

## Shell conventions

- Fish: use `set -gx` not `export`; abbreviations need `if status is-interactive`
- Bash/zsh: tool integrations (starship, zoxide, fzf, etc.) must be inside an interactive guard (`[[ $- == *i* ]]` / `[[ -o interactive ]]`)
- The `_init_cached` / `init_cached` pattern caches init script output by binary mtime — don't replace with direct `eval`/`source` calls; check for empty output and delete the cache file if blank
- `source_if_exists` is **not defined** in fish — use `test -f $file && source $file`

## Homebrew / packages

- `packages/brewfile.tmpl` uses `$is_container` (true when `/.dockerenv` exists or `$CI` is set) to skip heavy packages in CI
- On Linux, Homebrew prefix is always `/home/linuxbrew/.linuxbrew` (baked at template render time — not runtime-detected)
- macOS CI installs packages with `brew install fish jq ...` rather than running the full Brewfile (saves time)

## CI

Three jobs in `.github/workflows/test-dotfiles.yml`:
- **test-ubuntu** — native `ubuntu-latest`, installs bats + chezmoi, validates templates, runs bootstrap, runs bats tests; Homebrew cached by brewfile hash
- **test-macos** — `macos-latest`, uses `get.chezmoi.io` (not a pinned version), Homebrew download cache on `~/Library/Caches/Homebrew`
- **test-windows** — PowerShell syntax check, Pester unit tests, chezmoi dry-run

## Branches

- **main** — the only long-lived branch; push directly, no PRs needed for solo work
- **`feature/windows-support`** (remote only) — 23 commits of Windows-specific improvements not yet merged: OS guards on run scripts, scriptEnv PATH fixes, has1password detection, chezmoiignore for Windows-only files. Review before discarding.

## Known deferred items

From the July 2026 architectural review — intentionally not fixed yet:
- `dot_bashrc.tmpl` and `dot_zshrc.tmpl` are near-identical (~3 lines differ) — candidate for consolidation via `dot_config/shell/env.sh.tmpl`
- No `run_onchange_` script for brew packages on Linux/macOS (Windows has one via `run_onchange_windows_install-packages.ps1.tmpl`)
- Linux Homebrew prefix is baked at template render time, not detected at runtime
- `autoPush = true` in `[git]` — chezmoi will auto-push any plaintext credential accidentally added to source
- Windows CI only does `--dry-run`, never a full apply
- Zsh behaviour is not independently tested in bats (only bash and fish are)
