# Windows Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-class Windows support to the dotfiles repo — committing existing WIP files, reconciling the scoopfile, adding a chezmoi-driven scoop installer, a declarative winget package list with a manual install helper, and Windows bootstrap docs.

**Architecture:** Chezmoi manages all files; Windows-only scripts are gated by both `.chezmoiignore.tmpl` (file-level) and `$IsWindows` guards (script-level). The scoop install script uses the same content-hash pattern as the brew installer so it only re-runs when `scoopfile` changes.

**Tech Stack:** chezmoi, PowerShell 7, Scoop, winget, Go templates (chezmoi `.tmpl`)

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Modify | `run_before_00-install-prereqs.ps1` | Add `$IsWindows` guard |
| Modify | `run_onchange_after_06-setup-powershell.ps1` | Add `$IsWindows` guard |
| Modify | `dot_config/scoopfile` | Reconcile with actual scoop installs |
| Modify | `.chezmoiignore.tmpl` | Exclude new Windows files on non-Windows |
| Modify | `README.md` | Add Windows bootstrap section |
| Create | `run_onchange_after_07-install-scoop-packages.ps1.tmpl` | Auto-install scoop packages on chezmoi apply |
| Create | `dot_config/wingetfile` | Declarative winget package list |
| Create | `scripts/install-winget-packages.ps1` | Manual winget bootstrap helper |

---

### Task 1: Add `$IsWindows` guard to existing PS1 scripts and commit them

These three files are already written but untracked. We add the OS guard then commit all three together.

**Files:**
- Modify: `run_before_00-install-prereqs.ps1`
- Modify: `run_onchange_after_06-setup-powershell.ps1`
- Modify: `dot_config/powershell/profile.ps1.tmpl` (no content change — commit as-is)

- [ ] **Step 1: Add `$IsWindows` guard to `run_before_00-install-prereqs.ps1`**

Open the file. Insert the guard as the very first executable line (after any comments at the top, before `Set-StrictMode`):

```powershell
# Windows prerequisites: ensure scoop and core tools are installed.
# Runs before chezmoi applies the rest of the dotfiles.

if (-not $IsWindows) { Write-Host "Not Windows, skipping."; exit 0 }

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# ... rest of file unchanged
```

- [ ] **Step 2: Add `$IsWindows` guard to `run_onchange_after_06-setup-powershell.ps1`**

Insert the guard as the first executable line:

```powershell
# Wire the PowerShell profile to the chezmoi-managed file.
# chezmoi deploys the template to ~/.config/powershell/profile.ps1
# This script creates the directory for $PROFILE and adds a dot-source line
# pointing at the managed file, if it's not already there.

if (-not $IsWindows) { Write-Host "Not Windows, skipping."; exit 0 }

$managedProfile = Join-Path $HOME ".config\powershell\profile.ps1"
# ... rest of file unchanged
```

- [ ] **Step 3: Stage and commit all three existing Windows files**

```bash
git add run_before_00-install-prereqs.ps1 \
        run_onchange_after_06-setup-powershell.ps1 \
        dot_config/powershell/profile.ps1.tmpl
git commit -m "feat(windows): commit existing PS scripts and PowerShell profile"
```

Expected: commit succeeds with 3 files added.

---

### Task 2: Reconcile `dot_config/scoopfile`

Replace the file content to match what is actually Scoop-managed, removing packages handled by winget/cargo and adding missing ones.

**Files:**
- Modify: `dot_config/scoopfile`

- [ ] **Step 1: Replace scoopfile content**

Write the file with this exact content:

```
# Scoop packages (Windows equivalent of Brewfile)
# Format: [bucket/]package
# Install with: chezmoi apply  (triggers run_onchange_after_07)

# Buckets needed: extras, main (default)
# Add with: scoop bucket add extras

# --- Shell & editor ---
main/neovim
main/git

# --- Search & file tools ---
main/fzf
main/ripgrep
main/fd
main/bat
main/delta
main/jq
main/yq

# --- Build tools ---
main/cmake
main/llvm
main/dark

# --- Archive ---
main/7zip

# --- Python tooling ---
main/pixi
main/uv

# --- GUI ---
extras/powertoys
```

- [ ] **Step 2: Verify the diff looks correct**

```bash
git diff dot_config/scoopfile
```

Expected: additions include `7zip`, `cmake`, `dark`, `llvm`, `pixi`, `uv`, `powertoys`; removals include `oh-my-posh`, `starship`, `awscli`, `1password-cli`, `windows-terminal`, `go`, `nodejs`.

- [ ] **Step 3: Commit**

```bash
git add dot_config/scoopfile
git commit -m "feat(windows): reconcile scoopfile with actual scoop installs"
```

---

### Task 3: Add `run_onchange_after_07-install-scoop-packages.ps1.tmpl`

Auto-run chezmoi script that installs all packages from `scoopfile`. Mirrors the brewfile installer pattern. The `.tmpl` suffix lets chezmoi embed the scoopfile hash so it re-runs only on changes.

**Files:**
- Create: `run_onchange_after_07-install-scoop-packages.ps1.tmpl`

- [ ] **Step 1: Create the file**

```powershell
# Scoopfile hash: {{ include "dot_config/scoopfile" | sha256sum }}
# Re-runs automatically when scoopfile content changes.

if (-not $IsWindows) { Write-Host "Not Windows, skipping."; exit 0 }

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scoopfile = Join-Path $HOME ".config\scoopfile"
if (-not (Test-Path $scoopfile)) {
    Write-Host "No scoopfile found at $scoopfile, skipping."
    exit 0
}

Write-Host "Installing Scoop packages from $scoopfile..."

# Collect packages and bucket names
$packages = @()
$bucketsNeeded = @()

Get-Content $scoopfile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $packages += $line
    if ($line -contains "/") {
        $bucket = $line.Split("/")[0]
        $bucketsNeeded += $bucket
    }
}

# Ensure required buckets are present
$bucketsNeeded | Select-Object -Unique | ForEach-Object {
    $bucket = $_
    $existing = scoop bucket list | Select-String $bucket -Quiet
    if (-not $existing) {
        Write-Host "Adding scoop bucket: $bucket"
        scoop bucket add $bucket
    }
}

# Install packages (scoop no-ops if already installed)
foreach ($pkg in $packages) {
    $name = if ($pkg -contains "/") { $pkg.Split("/")[1] } else { $pkg }
    Write-Host "Installing $name..."
    scoop install $pkg
}

Write-Host "Scoop package installation complete!"
```

- [ ] **Step 2: Verify chezmoi can parse the template**

```bash
chezmoi execute-template < run_onchange_after_07-install-scoop-packages.ps1.tmpl
```

Expected: renders without error; the hash comment line shows a hex sha256 string.

- [ ] **Step 3: Commit**

```bash
git add run_onchange_after_07-install-scoop-packages.ps1.tmpl
git commit -m "feat(windows): add chezmoi-driven scoop package installer"
```

---

### Task 4: Add `dot_config/wingetfile` and `scripts/install-winget-packages.ps1`

Declarative winget package list plus a manual install helper. Not auto-run by chezmoi.

**Files:**
- Create: `dot_config/wingetfile`
- Create: `scripts/install-winget-packages.ps1`

- [ ] **Step 1: Create `dot_config/wingetfile`**

```
# Winget packages — manual install reference
# Run: scripts/install-winget-packages.ps1
# Install a single package: winget install --id <Id> --accept-source-agreements --accept-package-agreements

# --- Shell & prompt ---
JanDeDobbeleer.OhMyPosh
Microsoft.PowerShell
Microsoft.WindowsTerminal

# --- Dev tools ---
Git.Git
GitHub.cli
GoLang.Go
Rustlang.Rustup
Microsoft.VisualStudioCode

# --- Cloud & infra ---
Amazon.AWSCLI
Docker.DockerDesktop

# --- Security ---
AgileBits.1Password
AgileBits.1Password.CLI

# --- Build tools ---
Microsoft.VisualStudio.2022.Community

# --- Python ---
CondaForge.Miniforge3

# --- Apps ---
Anthropic.Claude
Microsoft.WSL
KYDronePilot.SpaceEye
```

- [ ] **Step 2: Create `scripts/` directory and `install-winget-packages.ps1`**

```powershell
# Manual winget bootstrap helper.
# Run this script once when setting up a new Windows machine.
# winget install is idempotent — already-installed packages are skipped.

if (-not $IsWindows) { Write-Host "Not Windows, skipping."; exit 0 }

$wingetfile = Join-Path $HOME ".config\wingetfile"
if (-not (Test-Path $wingetfile)) {
    Write-Host "No wingetfile found at $wingetfile"
    exit 1
}

Write-Host "Installing winget packages from $wingetfile..."

Get-Content $wingetfile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    Write-Host "Installing $line..."
    winget install --id $line --accept-source-agreements --accept-package-agreements
}

Write-Host "Winget package installation complete!"
```

- [ ] **Step 3: Commit both files**

```bash
git add dot_config/wingetfile scripts/install-winget-packages.ps1
git commit -m "feat(windows): add wingetfile and manual install helper"
```

---

### Task 5: Update `.chezmoiignore.tmpl`

Exclude the new Windows-only files on non-Windows systems.

**Files:**
- Modify: `.chezmoiignore.tmpl`

- [ ] **Step 1: Add new files to the non-Windows ignore block**

Find the existing non-Windows block (around line 29):

```
# Skip Windows-only files on non-Windows
{{- if ne .chezmoi.os "windows" }}
.config/powershell
run_before_00-install-prereqs.ps1
run_onchange_after_06-setup-powershell.ps1
{{ end -}}
```

Replace with:

```
# Skip Windows-only files on non-Windows
{{- if ne .chezmoi.os "windows" }}
.config/powershell
.config/wingetfile
run_before_00-install-prereqs.ps1
run_onchange_after_06-setup-powershell.ps1
run_onchange_after_07-install-scoop-packages.ps1.tmpl
scripts/install-winget-packages.ps1
{{ end -}}
```

- [ ] **Step 2: Verify chezmoi parses the ignore file cleanly**

```bash
chezmoi execute-template < .chezmoiignore.tmpl
```

Expected: renders without error; the Windows block lists all 6 entries.

- [ ] **Step 3: Commit**

```bash
git add .chezmoiignore.tmpl
git commit -m "feat(windows): exclude new Windows files on non-Windows via chezmoiignore"
```

---

### Task 6: Update `README.md` with Windows bootstrap section

Add a Windows subsection under "Quick Start", parallel to the existing macOS/Linux instructions.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Windows Quick Start section**

In `README.md`, find the existing `### Bootstrap Process` heading under `## Quick Start`. Insert a new `### Windows` subsection after the existing macOS/Linux bootstrap block (before `### What happens during bootstrap:`). Add:

````markdown
### Windows

**Step 1: Run the prerequisites script** (installs Scoop, oh-my-posh, 1Password CLI):

```powershell
# From an elevated PowerShell 7 prompt:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
& "$env:USERPROFILE\AppData\Local\Programs\chezmoi\chezmoi.exe" init --ssh --apply jesserobertson
# If chezmoi is not yet installed, install it via scoop first:
# scoop install main/chezmoi
```

Or run the prereqs script standalone before bootstrapping chezmoi:

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/jesserobertson/dotfiles/master/run_before_00-install-prereqs.ps1 | Invoke-Expression
```

**Step 2: Bootstrap chezmoi:**

```powershell
chezmoi init --ssh --apply jesserobertson
```

#### What happens during Windows bootstrap:

1. **Phase 0: Pre-installation** (`run_before_00-install-prereqs.ps1`)
   - Installs Scoop if not present
   - Adds `extras` and `versions` Scoop buckets
   - Installs 1Password CLI and oh-my-posh via Scoop

2. **Phase 1: Apply Dotfiles**
   - Chezmoi deploys `~/.config/powershell/profile.ps1` (oh-my-posh, PSReadLine, PATH)
   - Non-Windows configs (fish, tmux, alacritty) are skipped via `.chezmoiignore`

3. **Phase 2: Install Scoop Packages** (`run_onchange_after_07-install-scoop-packages.ps1.tmpl`)
   - Installs all packages from `~/.config/scoopfile`
   - Only re-runs when scoopfile content changes

4. **Phase 3: Wire PowerShell Profile** (`run_onchange_after_06-setup-powershell.ps1`)
   - Adds a dot-source line to `$PROFILE` pointing at the chezmoi-managed profile

#### Installing GUI apps and build tools (winget)

After bootstrap, run the winget helper manually to install heavier applications:

```powershell
~\scripts\install-winget-packages.ps1
```

This installs packages from `~/.config/wingetfile` (1Password, Docker, VS Code, Visual Studio, etc.).

#### Updating packages

```powershell
# Add a scoop package: edit ~/.config/scoopfile, then:
chezmoi apply   # triggers re-run of scoop installer

# Add a winget package: edit ~/.config/wingetfile, then run manually:
~\scripts\install-winget-packages.ps1
```
````

- [ ] **Step 2: Verify the README renders correctly**

Open `README.md` and visually confirm the new section appears in the right place and all code blocks are properly closed.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add Windows bootstrap section to README"
```

---

## Self-Review

**Spec coverage:**
- ✅ Commit existing untracked files → Task 1
- ✅ Update scoopfile → Task 2
- ✅ Add scoop install script → Task 3
- ✅ Add wingetfile → Task 4
- ✅ Add winget helper script → Task 4
- ✅ Update `.chezmoiignore.tmpl` → Task 5
- ✅ Update README → Task 6
- ✅ OS guards on all PS1 scripts → Task 1 (existing), Task 3 (new script), Task 4 (winget helper)

**No placeholders:** All steps contain exact file content or commands.

**Type/name consistency:** `scoopfile` path referenced as `~/.config/scoopfile` consistently across Tasks 2, 3, 6. Script names match `.chezmoiignore.tmpl` entries in Task 5 exactly.
