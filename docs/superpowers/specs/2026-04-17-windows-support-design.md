# Windows Support Design

**Date:** 2026-04-17
**Status:** Approved

## Overview

Add first-class Windows support to the dotfiles repo, making this machine (Windows 11, managed via chezmoi) a fully reproducible environment alongside the existing macOS/Linux support. Several Windows-specific files already exist as untracked work-in-progress; this design commits and completes them.

## Scope

1. Commit existing untracked Windows files
2. Update `scoopfile` to match what is actually installed via Scoop
3. Add `run_onchange_after_07-install-scoop-packages.ps1.tmpl.tmpl` — auto-run Scoop installer
4. Add `dot_config/wingetfile` — declarative list of winget packages
5. Add `scripts/install-winget-packages.ps1` — manual winget bootstrap helper
6. Update `.chezmoiignore.tmpl` — exclude Windows-only files on non-Windows
7. Update `README.md` — Windows bootstrap section

## Files Changed

### Commit existing untracked files (no content changes)

- `run_before_00-install-prereqs.ps1` — installs Scoop, 1Password CLI, oh-my-posh; runs before chezmoi applies
- `run_onchange_after_06-setup-powershell.ps1` — wires `~/.config/powershell/profile.ps1` into `$PROFILE` via dot-source
- `dot_config/powershell/profile.ps1.tmpl` — PowerShell profile: oh-my-posh (bubbles theme), PSReadLine, PATH management, optional 1Password SSH agent

### `dot_config/scoopfile` (updated)

Reconcile the file with what is actually Scoop-managed on this machine. Remove packages that are managed by winget or cargo instead; add packages that are installed but missing.

**Keep (already in scoop):** `neovim`, `git` (keep as cross-reference even though winget has it too)
- `fzf`, `ripgrep`, `fd`, `bat`, `delta`, `jq`, `yq` → keep (good CLI tools for scoop)

**Add (in scoop, missing from file):**
- Build tools: `7zip`, `cmake`, `dark`, `llvm`
- Python tooling: `pixi`, `uv`
- GUI: `powertoys`

**Remove (not in scoop — managed elsewhere):**
- `oh-my-posh` → winget (`JanDeDobbeleer.OhMyPosh`)
- `awscli` → winget (`Amazon.AWSCLI`)
- `1password-cli` → winget (`AgileBits.1Password.CLI`)
- `windows-terminal` → winget (`Microsoft.WindowsTerminal`)
- `go` → winget (`GoLang.Go`)
- `nodejs` → winget 
- `starship` → cargo

### `run_onchange_after_07-install-scoop-packages.ps1.tmpl.tmpl` (new)

Auto-run script triggered by chezmoi when `scoopfile` content changes. Pattern mirrors `run_after_00-install-brews.sh.tmpl`.

- Has `.tmpl` suffix so chezmoi processes it as a template; header comment embeds `{{ include "dot_config/scoopfile" | sha256sum }}` so chezmoi re-runs on scoopfile changes
- Reads `~/.config/scoopfile`, skips blank lines and `#` comments
- Parses optional `bucket/package` format; collects unique bucket names and adds any missing ones via `scoop bucket add`
- Calls `scoop install <package>` for each entry (idempotent — scoop no-ops if already installed)

### `dot_config/wingetfile` (new)

Plain text file, one winget package ID per line, `#` comments for grouping. This is a reference/bootstrap list — not auto-installed by chezmoi.

Categories:
- Shell & prompt: `JanDeDobbeleer.OhMyPosh`, `Microsoft.PowerShell`, `Microsoft.WindowsTerminal`
- Dev tools: `Git.Git`, `GitHub.cli`, `GoLang.Go`, `Rustlang.Rustup`, `Microsoft.VisualStudioCode`
- Cloud & infra: `Amazon.AWSCLI`, `Docker.DockerDesktop`
- Security: `AgileBits.1Password`, `AgileBits.1Password.CLI`
- Build tools: `Microsoft.VisualStudio.2022.Community`
- Python: `CondaForge.Miniforge3`
- Apps: `Anthropic.Claude`, `Microsoft.WSL`, `KYDronePilot.SpaceEye`

### `scripts/install-winget-packages.ps1` (new)

Manual bootstrap helper. Reads `~/.config/wingetfile`, skips blanks and comments, and calls:
```powershell
winget install --id <pkg> --accept-source-agreements --accept-package-agreements
```
Not wired into chezmoi's run system — invoke manually when setting up a new machine.

### `.chezmoiignore.tmpl` (updated)

Add to the non-Windows block (alongside existing `run_before_00-install-prereqs.ps1`):
```
run_onchange_after_07-install-scoop-packages.ps1.tmpl
scripts/install-winget-packages.ps1
.config/wingetfile
```

### `README.md` (updated)

Add a **Windows** subsection under "Quick Start":

1. **Prerequisites** — run `run_before_00-install-prereqs.ps1` first (installs Scoop, oh-my-posh, 1Password CLI), then bootstrap chezmoi with `chezmoi init --ssh --apply jesserobertson`
2. **Bootstrap phases** (parallel to macOS/Linux):
   - Phase 0: prereqs (Scoop, tools)
   - Phase 1: apply dotfiles (PowerShell profile → `~/.config/powershell/profile.ps1`)
   - Phase 2: Scoop packages (`run_onchange_after_07`)
   - Phase 3: wire profile (`run_onchange_after_06`)
3. **Winget helper** — run `scripts/install-winget-packages.ps1` manually for GUI apps and build tools
4. **Updating packages** — edit scoopfile/wingetfile, run `chezmoi apply`

## OS Guard Clauses

All install scripts must have an internal OS guard as defense-in-depth alongside `.chezmoiignore.tmpl`.

**Shell scripts** (`run_before_00-install-prereqs.sh`, `run_after_00-install-brews.sh.tmpl`) already guard via `case "$(uname -s)"` — no change needed.

**PowerShell scripts** — add at the top of each `.ps1` / `.ps1.tmpl`:
```powershell
if ($env:OS -ne "Windows_NT") { Write-Host "Not Windows, skipping."; exit 0 }
```
Applies to:
- `run_before_00-install-prereqs.ps1` (existing, untracked)
- `run_onchange_after_06-setup-powershell.ps1` (existing, untracked)
- `run_onchange_after_07-install-scoop-packages.ps1.tmpl` (new)

## Chezmoi Integration Notes

- `.ps1` scripts are Windows-only by chezmoi convention, but we also add them to `.chezmoiignore.tmpl` for explicitness
- `scoopfile` content hash in the script header triggers re-runs only on package list changes
- `run_before_` (prereqs) runs before apply; `run_onchange_after_` (scoop install, profile wiring) runs after
- The `scriptEnv.PATH` in `chezmoi.toml.tmpl` already includes Scoop shims for Windows, so scripts can find Scoop-installed tools

## Out of Scope

- Fish shell, tmux, alacritty on Windows (excluded via `.chezmoiignore.tmpl`)
- Automated winget installs (too slow/heavy for chezmoi run scripts; manual is fine)
- WSL dotfiles management (WSL has its own Linux environment)
