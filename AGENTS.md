# Agent Instructions

Personal dotfiles managed with [chezmoi](https://chezmoi.io). Supports macOS, Linux (via Homebrew), and Windows.

## Repository structure

```
.chezmoi.toml.tmpl          # Single source of truth for all template variables
dot_bashrc.tmpl             # Bash config (renders to ~/.bashrc)
dot_zshrc.tmpl              # Zsh config (renders to ~/.zshrc)
dot_config/fish/            # Fish config
dot_config/powershell/      # PowerShell config (Windows)
dot_config/bash/env.sh.tmpl # Single source of truth for env vars; zsh/env.zsh and fish/env.fish mirror it
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

## Setup is automated via run_onchange_ scripts

`chezmoi apply` now runs everything in order:

| Script | Trigger | What it does |
|--------|---------|--------------|
| `run_before_00-install-prereqs.sh.tmpl` | always | installs Homebrew (Unix only) |
| `run_onchange_after_00-install-brews.sh.tmpl` | brewfile hash | `brew bundle install` |
| `run_onchange_after_01-install-rust.fish.tmpl` | toolchain marker | rustup + stable/nightly |
| `run_onchange_after_02-install-crates.fish.tmpl` | cratefile hash | `cargo install` |
| `run_onchange_after_03-install-extras.sh.tmpl` | pixi/skillfile/mcp-servers hashes (independent, bundled in one script) | pixi global install + Claude Code skills + MCP servers (macOS only) |
| `run_once_after_06-install-tmux-plugins.sh.tmpl` | once | TPM install |
| `run_onchange_after_07-setup-powershell.ps1.tmpl` | — | wire `$PROFILE` (Windows only) |
| `run_onchange_windows_install-packages.ps1.tmpl` | scoop+crate hash | Scoop + cargo (Windows only) |

Unix-only scripts and Windows-only scripts are mutually excluded via `.chezmoiignore.tmpl`'s
target-filename matching (`{{- if eq .chezmoi.os "windows" }}...target names...{{ end -}}` and
the inverse), not a per-script runtime OS guard — the actual target filename (after chezmoi
strips the `run_onchange_after_NN-`/`.tmpl` parts, e.g. `03-install-extras.sh`) must be kept in
sync with that ignore list whenever one of these scripts is renamed.

