# Optional Installs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all `run_*` install scripts out of chezmoi management into a `scripts/` directory with a `Makefile`, so `chezmoi apply` only touches dotfiles.

**Architecture:** Each `run_*` script is moved to `scripts/<name>` with readable names, chezmoi template vars replaced by env var defaults, and OS guards inlined. A `Makefile` provides named targets. Old `run_*` files are deleted and `.chezmoiignore` entries cleaned up.

**Tech Stack:** bash, fish, PowerShell, GNU Make, chezmoi

---

## File Map

**Create:**
- `scripts/install-prereqs.sh` ← `run_before_00-install-prereqs.sh.tmpl`
- `scripts/install-brew.sh` ← `run_after_00-install-brews.sh.tmpl`
- `scripts/install-pixi.sh` ← `run_onchange_install-pixi-global.sh.tmpl`
- `scripts/update-tmux.sh` ← `run_after_04-update-tmux.bash.tmpl`
- `scripts/install-rust.fish` ← `run_onchange_after_01-install-rust.fish.tmpl`
- `scripts/install-crates.fish` ← `run_onchange_after_02-install-crates.fish.tmpl`
- `scripts/install-python.fish` ← `run_onchange_after_03-install-python.fish.tmpl`
- `scripts/install-skills.fish` ← `run_onchange_after_04-install-skills.fish.tmpl`
- `scripts/install-mcp-servers.fish` ← `run_onchange_after_05-install-mcp-servers.fish.tmpl`
- `scripts/install-prereqs.ps1` ← `run_before_00-install-prereqs.ps1` (untracked)
- `scripts/setup-powershell.ps1` ← `run_onchange_after_06-setup-powershell.ps1`
- `Makefile`

**Modify:**
- `.chezmoiignore` — remove `run_*` entry
- `.chezmoiignore.tmpl` — commit unstaged Windows support changes, then remove all `run_*` filename entries from both OS guard blocks
- `README.md` — replace outdated bootstrap/phase sections with new Usage section

**Delete:**
- `run_before_00-install-prereqs.sh.tmpl`
- `run_after_00-install-brews.sh.tmpl`
- `run_onchange_install-pixi-global.sh.tmpl`
- `run_after_04-update-tmux.bash.tmpl`
- `run_onchange_after_01-install-rust.fish.tmpl`
- `run_onchange_after_02-install-crates.fish.tmpl`
- `run_onchange_after_03-install-python.fish.tmpl`
- `run_onchange_after_04-install-skills.fish.tmpl`
- `run_onchange_after_05-install-mcp-servers.fish.tmpl`
- `run_onchange_after_06-setup-powershell.ps1`

---

### Task 1: Migrate bash scripts (prereqs, pixi, tmux)

**Files:**
- Create: `scripts/install-prereqs.sh`
- Create: `scripts/install-pixi.sh`
- Create: `scripts/update-tmux.sh`

- [ ] **Step 1: Create `scripts/` directory**

```bash
mkdir -p scripts
```

- [ ] **Step 2: Write `scripts/install-prereqs.sh`**

Strip the `{{- if ne .chezmoi.os "windows" -}}` / `{{- end -}}` wrapper — the script already handles macOS/Linux internally. No other template vars to replace.

```bash
#!/bin/bash
set -eu

## INSTALL HOMEBREW
echo "Installing Homebrew..."

case "$(uname -s)" in
Darwin)
    echo "Detected macOS"
    OS="darwin"
    if [ -x "/opt/homebrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    elif [ -x "/usr/local/bin/brew" ]; then
        HOMEBREW_PREFIX="/usr/local"
    else
        HOMEBREW_PREFIX="/opt/homebrew"
    fi
    PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
    ;;
Linux)
    echo "Detected Linux"
    OS="linux"
    if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    elif [ -x "${HOME}/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="${HOME}/.linuxbrew"
    else
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    fi
    PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
    ;;
*)
    echo "Unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

echo "Using Homebrew prefix: ${HOMEBREW_PREFIX}"
BREW_BIN=$(which brew 2>/dev/null || true)

if [ -n "${BREW_BIN}" ] && [ -x "${BREW_BIN}" ]; then
  echo "Homebrew already installed at ${BREW_BIN}"
else
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
fi

## INSTALL 1PASSWORD (needed for templates, optional in CI)
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ]; then
  echo "CI environment detected, skipping 1Password CLI installation"
elif [ "${OS}" = "linux" ]; then
  echo "Linux detected - 1Password CLI installation skipped (cask not available)"
  echo "To install manually, see: https://developer.1password.com/docs/cli/get-started/"
else
  OP_BIN=$(which op 2>/dev/null || true)
  if [ -n "${OP_BIN}" ] && [ -x "${OP_BIN}" ]; then
    echo "1Password (op) already installed at ${OP_BIN}"
  else
    echo "1Password not found. Installing..."
    brew install --cask 1password-cli
  fi
fi
```

- [ ] **Step 3: Write `scripts/install-pixi.sh`**

Strip OS wrapper, no other template vars:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Python development environment
pixi global install --environment python python uv ruff mypy

# HTTP utilities (library env, no exposed binaries)
pixi global install --environment requests \
  requests
```

- [ ] **Step 4: Write `scripts/update-tmux.sh`**

Strip OS wrapper. Script already uses `${FORCE:-false}` — no template vars:

```bash
#!/usr/bin/env bash
set -euo pipefail

TPM_DIR="$HOME/.config/tmux/plugins/tpm"

if [ "${FORCE:-false}" = "true" ]; then
    echo "Force mode enabled - removing existing TPM installation..."
    rm -rf "$TPM_DIR"
fi

if [ -d "$TPM_DIR" ]; then
    echo "TPM already installed at $TPM_DIR"
    exit 0
fi

echo "Installing tmux plugin manager..."
git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
echo "TPM installed successfully"
```

- [ ] **Step 5: Syntax-check all three scripts**

```bash
bash -n scripts/install-prereqs.sh && echo "install-prereqs.sh OK"
bash -n scripts/install-pixi.sh && echo "install-pixi.sh OK"
bash -n scripts/update-tmux.sh && echo "update-tmux.sh OK"
```

Expected: three `OK` lines, no errors.

- [ ] **Step 6: Commit**

```bash
git add scripts/install-prereqs.sh scripts/install-pixi.sh scripts/update-tmux.sh
git commit -m "feat: add scripts/install-prereqs.sh, install-pixi.sh, update-tmux.sh"
```

---

### Task 2: Migrate `install-brew.sh`

**Files:**
- Create: `scripts/install-brew.sh`

- [ ] **Step 1: Write `scripts/install-brew.sh`**

Changes from `run_after_00-install-brews.sh.tmpl`:
- Remove `{{- if ne .chezmoi.os "windows" -}}` / `{{- end -}}` wrapper
- Remove `# Brewfile hash: {{ include "dot_config/brewfile.tmpl" | sha256sum }}` line (chezmoi hashing, no longer needed)
- Replace `{{ .xdg_config_home }}` with `${XDG_CONFIG_HOME:-$HOME/.config}`
- Replace `{{- if hasKey .chezmoi "force" }}...{{- end }}` template block with `${FORCE:-false}` check

```bash
#!/bin/bash
set -eu

echo "Installing Homebrew packages..."

case "$(uname -s)" in
Darwin)
    if [ -x "/opt/homebrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    elif [ -x "/usr/local/bin/brew" ]; then
        HOMEBREW_PREFIX="/usr/local"
    else
        HOMEBREW_PREFIX="/opt/homebrew"
    fi
    ;;
Linux)
    if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    elif [ -x "${HOME}/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="${HOME}/.linuxbrew"
    else
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    fi
    ;;
*)
    echo "Unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

export PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
echo "Using Homebrew prefix: ${HOMEBREW_PREFIX}"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BREWFILE="${XDG_CONFIG_HOME}/brewfile"
echo "Installing packages from ${BREWFILE}..."

if [ "${FORCE:-false}" = "true" ]; then
    echo "Force mode enabled - reinstalling all packages..."
    brew bundle install --force --file="${BREWFILE}" --verbose
else
    brew bundle install --file="${BREWFILE}" --verbose
fi

echo "Homebrew package installation complete!"
```

- [ ] **Step 2: Syntax-check**

```bash
bash -n scripts/install-brew.sh && echo "install-brew.sh OK"
```

Expected: `install-brew.sh OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/install-brew.sh
git commit -m "feat: add scripts/install-brew.sh"
```

---

### Task 3: Migrate `install-rust.fish`

**Files:**
- Create: `scripts/install-rust.fish`

- [ ] **Step 1: Write `scripts/install-rust.fish`**

Changes from `run_onchange_after_01-install-rust.fish.tmpl`:
- Remove `{{- if ne .chezmoi.os "windows" -}}` / `{{- end -}}` wrapper
- Source `env.fish` first, then use `set -q VAR; or set -gx VAR default` for `RUSTUP_HOME` and `CARGO_HOME`
- Replace `{{ .rustup_home }}` → `$RUSTUP_HOME`
- Replace `{{ .cargo_home }}` → `$CARGO_HOME`
- Replace `{{- if hasKey .chezmoi "force" }}...{{- end }}` template block with `if test "$FORCE" = "true"`

```fish
#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping Rust installation"
    exit 0
end

# Source env.fish for correct XDG/tool paths; fall back to XDG defaults
if test -f ~/.config/fish/env.fish
    source ~/.config/fish/env.fish
end
set -q RUSTUP_HOME; or set -gx RUSTUP_HOME "$HOME/.local/share/rustup"
set -q CARGO_HOME;  or set -gx CARGO_HOME "$HOME/.local/share/cargo"
set PATH "$CARGO_HOME/bin" $PATH

if not test -d "$CARGO_HOME/bin"
    if type -q rustup
        echo "rustup found but not in correct location, removing old installation..."
        rustup self uninstall -y 2>/dev/null; or true
        brew uninstall rustup 2>/dev/null; or true
        rm -rf ~/.cargo ~/.rustup 2>/dev/null; or true
    end

    echo "Installing rustup to custom location..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    set PATH "$CARGO_HOME/bin" $PATH
end

echo "Checking Rust toolchain..."
if type -q rustup
    if test "$FORCE" = "true"
        echo "Force mode enabled - reinstalling Rust toolchains..."
        rustup toolchain uninstall stable 2>/dev/null; or true
        rustup toolchain uninstall nightly 2>/dev/null; or true
        rustup toolchain install stable
        rustup toolchain install nightly
    else
        if not rustup toolchain list | grep -q 'stable'
            echo "Installing stable toolchain..."
            rustup toolchain install stable
        else
            echo "Stable toolchain already installed"
        end

        if not rustup toolchain list | grep -q 'nightly'
            echo "Installing nightly toolchain..."
            rustup toolchain install nightly
        else
            echo "Nightly toolchain already installed"
        end
    end

    echo "Rust toolchain check complete!"
else
    echo "Warning: rustup not found, skipping Rust toolchain installation"
end
```

- [ ] **Step 2: Syntax-check**

```bash
fish -n scripts/install-rust.fish && echo "install-rust.fish OK"
```

Expected: `install-rust.fish OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/install-rust.fish
git commit -m "feat: add scripts/install-rust.fish"
```

---

### Task 4: Migrate `install-crates.fish`

**Files:**
- Create: `scripts/install-crates.fish`

- [ ] **Step 1: Write `scripts/install-crates.fish`**

Changes from `run_onchange_after_02-install-crates.fish.tmpl`:
- Remove OS wrapper and `# Crates list hash: ...` comment line
- Source `env.fish` first, then default `RUSTUP_HOME`, `CARGO_HOME`, `XDG_CONFIG_HOME`
- Replace all `{{ .rustup_home }}`, `{{ .cargo_home }}`, `{{ .xdg_config_home }}` with their `$VAR` equivalents
- Replace `{{- if hasKey .chezmoi "force" }}` block with `if test "$FORCE" = "true"`

```fish
#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping Rust crate installation"
    exit 0
end

if test -f ~/.config/fish/env.fish
    source ~/.config/fish/env.fish
end
set -q RUSTUP_HOME;     or set -gx RUSTUP_HOME "$HOME/.local/share/rustup"
set -q CARGO_HOME;      or set -gx CARGO_HOME "$HOME/.local/share/cargo"
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
set PATH "$CARGO_HOME/bin" $PATH

echo "Installing Rust crates..."

if not type -q cargo
    echo "Error: cargo not found. Please ensure Rust is installed."
    echo "RUSTUP_HOME: $RUSTUP_HOME"
    echo "CARGO_HOME: $CARGO_HOME"
    echo "Current PATH: $PATH"
    echo "Contents of $CARGO_HOME/bin:"
    ls -la "$CARGO_HOME/bin" 2>/dev/null; or echo "Directory does not exist"
    exit 1
end

set CRATES_FILE "$XDG_CONFIG_HOME/cratefile"
if not test -f "$CRATES_FILE"
    echo "Error: Crates file not found at $CRATES_FILE"
    exit 1
end

set CRATES (grep -v '^#' "$CRATES_FILE" | grep -v '^$' | sed 's/#.*//')

if test -z "$CRATES"
    echo "No crates to install"
    exit 0
end

echo "Crates to install: $CRATES"

if test "$FORCE" = "true"
    echo "Force mode enabled - reinstalling all crates..."
    for crate in $CRATES
        echo "Reinstalling $crate..."
        cargo install --force "$crate"
    end
else
    for crate in $CRATES
        if not cargo install --list | grep -q "^$crate v"
            echo "Installing $crate..."
            cargo install "$crate"
        else
            echo "$crate already installed"
        end
    end
end

echo "Rust crates installation complete!"
```

- [ ] **Step 2: Syntax-check**

```bash
fish -n scripts/install-crates.fish && echo "install-crates.fish OK"
```

Expected: `install-crates.fish OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/install-crates.fish
git commit -m "feat: add scripts/install-crates.fish"
```

---

### Task 5: Migrate remaining fish scripts

**Files:**
- Create: `scripts/install-python.fish`
- Create: `scripts/install-skills.fish`
- Create: `scripts/install-mcp-servers.fish`

- [ ] **Step 1: Write `scripts/install-python.fish`**

Strip OS wrapper. No template vars — script is already pure fish:

```fish
#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping pixi global sync"
    exit 0
end

echo "Syncing pixi global environments..."

if not type -q pixi
    echo "Error: pixi not found. Please ensure pixi is installed via Homebrew."
    echo "Run: brew install pixi"
    exit 1
end

pixi global sync

echo "Pixi global sync complete!"
echo ""
echo "Python tools have been installed globally via pixi"
echo "Available commands:"
echo "  - python / python3"
echo "  - ipython"
echo "  - jupyter / jupyter-lab"
echo "  - marimo"
echo "  - ruff"
echo "  - pyright"
echo "  - mypy"
echo ""
echo "To add more packages, edit: ~/.pixi/manifests/pixi-global.toml"
echo "Then run: pixi global sync"
```

- [ ] **Step 2: Write `scripts/install-skills.fish`**

Changes:
- Remove OS wrapper and `# Claude Code skills list hash: ...` comment
- Replace `{{ .chezmoi.homeDir }}` with `$HOME`

```fish
#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping Claude Code skill installation"
    exit 0
end

echo "Installing Claude Code skills..."

if not type -q git
    echo "Error: git not found. Please ensure git is installed."
    exit 1
end

set SKILLS_DIR "$HOME/.claude/skills"
set SKILLFILE "$HOME/.claude/skillfile"

if not test -d "$SKILLS_DIR"
    echo "Creating skills directory at $SKILLS_DIR..."
    mkdir -p "$SKILLS_DIR"
end

if not test -f "$SKILLFILE"
    echo "No skillfile found at $SKILLFILE - skipping skill installation"
    exit 0
end

set SKILL_URLS (grep -v '^#' "$SKILLFILE" | grep -v '^$' | sed 's/#.*//')

if test -z "$SKILL_URLS"
    echo "No skills to install"
    exit 0
end

echo "Skills to process: "(count $SKILL_URLS)

for url in $SKILL_URLS
    set repo_name (basename "$url" .git)
    set skill_path "$SKILLS_DIR/$repo_name"

    if test -d "$skill_path"
        echo "Updating skill: $repo_name..."
        cd "$skill_path"

        if test -d .git
            git fetch origin
            if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1
                git pull --ff-only
                echo "  Updated $repo_name"
            else
                echo "  $repo_name is not tracking a remote branch - skipping update"
            end
        else
            echo "  Warning: $skill_path exists but is not a git repository"
        end
    else
        echo "Installing skill: $repo_name..."
        if git clone "$url" "$skill_path"
            echo "  Installed $repo_name successfully"
        else
            echo "  Error: Failed to clone $repo_name from $url"
        end
    end
end

echo ""
echo "Claude Code skills installation complete!"
echo "Installed skills are located at: $SKILLS_DIR"
```

- [ ] **Step 3: Write `scripts/install-mcp-servers.fish`**

Changes:
- Remove OS wrapper and hash comment line
- Replace `{{- if eq .chezmoi.os "darwin" }}...{{- else }}...{{- end }}` with inline `uname -s` check

```fish
#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping Claude Code MCP server setup"
    exit 0
end

if test (uname -s) != "Darwin"
    echo "MCP server setup is only available on macOS"
    exit 0
end

echo "Setting up Claude Code MCP servers..."

if not type -q npx
    echo "Warning: npx not found. Things MCP requires Node.js and npm."
    echo "Install Node.js from https://nodejs.org/ or via Homebrew: brew install node"
    exit 1
end

echo "Verifying Things MCP server..."
if npx -y @hald/things-mcp --version >/dev/null 2>&1
    echo "  Things MCP server is ready"
else
    echo "  Installing Things MCP server..."
    npx -y @hald/things-mcp --version
end

echo ""
echo "MCP servers setup complete!"
echo "Things integration is available in Claude Code sessions."
```

- [ ] **Step 4: Syntax-check all three**

```bash
fish -n scripts/install-python.fish && echo "install-python.fish OK"
fish -n scripts/install-skills.fish && echo "install-skills.fish OK"
fish -n scripts/install-mcp-servers.fish && echo "install-mcp-servers.fish OK"
```

Expected: three `OK` lines.

- [ ] **Step 5: Commit**

```bash
git add scripts/install-python.fish scripts/install-skills.fish scripts/install-mcp-servers.fish
git commit -m "feat: add scripts/install-python.fish, install-skills.fish, install-mcp-servers.fish"
```

---

### Task 6: Migrate PowerShell scripts

**Files:**
- Create: `scripts/install-prereqs.ps1`
- Create: `scripts/setup-powershell.ps1`

- [ ] **Step 1: Write `scripts/install-prereqs.ps1`**

The untracked `run_before_00-install-prereqs.ps1` is plain PS1 with no template vars — copy content verbatim:

```powershell
# Windows prerequisites: ensure scoop and core tools are installed.
# Runs before chezmoi applies the rest of the dotfiles.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Scoop ---
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else {
    Write-Host "scoop already installed, skipping."
}

# Ensure shims are on PATH for the rest of this script
$scoopShims = Join-Path $HOME "scoop\shims"
if ($env:PATH -notlike "*$scoopShims*") {
    $env:PATH = "$scoopShims;$env:PATH"
}

# --- Core scoop buckets ---
$buckets = @("extras", "versions")
foreach ($bucket in $buckets) {
    if (-not (scoop bucket list | Select-String $bucket -Quiet)) {
        Write-Host "Adding scoop bucket: $bucket"
        scoop bucket add $bucket
    }
}

# --- 1Password CLI ---
if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
    Write-Host "Installing 1Password CLI..."
    scoop install extras/1password-cli
} else {
    Write-Host "1Password CLI (op) already installed, skipping."
}

# --- oh-my-posh ---
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Host "Installing oh-my-posh..."
    scoop install main/oh-my-posh
} else {
    Write-Host "oh-my-posh already installed, skipping."
}
```

- [ ] **Step 2: Write `scripts/setup-powershell.ps1`**

Copy `run_onchange_after_06-setup-powershell.ps1` verbatim — no template vars:

```powershell
# Write the PowerShell $PROFILE wrapper that dot-sources the chezmoi-managed profile.
# chezmoi deploys the real config to ~/.config/powershell/profile.ps1 via template.
# $PROFILE lives in a user-specific location (e.g. OneDrive\Documents), so we write
# it here rather than trying to manage the path in chezmoi's source directory.

$managedProfile = Join-Path $HOME ".config\powershell\profile.ps1"

$wrapperContent = @"
# Generated by chezmoi - do not edit directly.
# Edit dot_config/powershell/profile.ps1.tmpl in your dotfiles repo instead.
. "$managedProfile"
"@

$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

Set-Content -Path $PROFILE -Value $wrapperContent -Encoding UTF8
```

- [ ] **Step 3: Syntax-check (PowerShell parse only)**

```powershell
pwsh -NonInteractive -Command "& { [scriptblock]::Create((Get-Content -Raw 'scripts/install-prereqs.ps1')) | Out-Null; Write-Host 'install-prereqs.ps1 OK' }"
pwsh -NonInteractive -Command "& { [scriptblock]::Create((Get-Content -Raw 'scripts/setup-powershell.ps1')) | Out-Null; Write-Host 'setup-powershell.ps1 OK' }"
```

Expected: both `OK` lines.

- [ ] **Step 4: Commit**

```bash
git add scripts/install-prereqs.ps1 scripts/setup-powershell.ps1
git commit -m "feat: add scripts/install-prereqs.ps1, setup-powershell.ps1"
```

---

### Task 7: Add Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Write `Makefile`**

Note: recipe lines must use actual tab characters, not spaces.

```makefile
.PHONY: bootstrap dotfiles prereqs brew rust crates python skills mcp pixi tmux powershell

bootstrap: dotfiles prereqs brew rust crates python skills mcp pixi  ## Full new-machine setup

dotfiles:  ## Apply dotfiles (chezmoi apply)
	chezmoi apply

prereqs:  ## Homebrew + 1Password (macOS/Linux) or Scoop + tools (Windows)
ifeq ($(OS),Windows_NT)
	powershell -ExecutionPolicy Bypass -File scripts/install-prereqs.ps1
else
	bash scripts/install-prereqs.sh
endif

brew:  ## Install Homebrew packages from Brewfile
	bash scripts/install-brew.sh

rust:  ## Install Rust toolchain via rustup
	fish scripts/install-rust.fish

crates:  ## Install Rust crates
	fish scripts/install-crates.fish

python:  ## Sync pixi global environments
	fish scripts/install-python.fish

skills:  ## Install Claude Code skills
	fish scripts/install-skills.fish

mcp:  ## Install MCP servers (macOS only)
	fish scripts/install-mcp-servers.fish

pixi:  ## Install pixi global packages
	bash scripts/install-pixi.sh

tmux:  ## Install/update tmux plugin manager
	bash scripts/update-tmux.sh

powershell:  ## Write PowerShell $PROFILE wrapper (Windows)
	powershell -ExecutionPolicy Bypass -File scripts/setup-powershell.ps1
```

- [ ] **Step 2: Verify Makefile dry-run**

```bash
make -n bootstrap
```

Expected: prints the commands that would run (`chezmoi apply`, `bash scripts/install-prereqs.sh`, `bash scripts/install-brew.sh`, etc.) without executing them. No "missing separator" or parse errors.

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "feat: add Makefile with bootstrap and individual install targets"
```

---

### Task 8: Delete old run_* files and clean up chezmoiignore

**Files:**
- Delete: all `run_*` files in repo root
- Modify: `.chezmoiignore` — remove `run_*` line
- Modify: `.chezmoiignore.tmpl` — commit existing Windows changes, then remove `run_*` filename entries

- [ ] **Step 1: Delete all run_* files**

```bash
git rm run_before_00-install-prereqs.sh.tmpl \
       run_after_00-install-brews.sh.tmpl \
       run_onchange_install-pixi-global.sh.tmpl \
       run_after_04-update-tmux.bash.tmpl \
       run_onchange_after_01-install-rust.fish.tmpl \
       run_onchange_after_02-install-crates.fish.tmpl \
       run_onchange_after_03-install-python.fish.tmpl \
       run_onchange_after_04-install-skills.fish.tmpl \
       run_onchange_after_05-install-mcp-servers.fish.tmpl \
       run_onchange_after_06-setup-powershell.ps1
```

The untracked `run_before_00-install-prereqs.ps1` in repo root was already migrated to `scripts/install-prereqs.ps1` in Task 6. Delete it:

```bash
rm run_before_00-install-prereqs.ps1
```

- [ ] **Step 2: Update `.chezmoiignore`**

Remove the `# Ignore all run and test scripts` comment block and `run_*` entry. The file should go from:

```
# Ignore all run and test scripts
run_*
test*.sh
```

to:

```
test*.sh
```

Full resulting `.chezmoiignore` after the edit:

```
README.md
LICENSE
Brewfile
Crates
chezmoi.yaml
chezmoi.toml
*swp
temp/**

# Ignore all private configuration files
configs_*

test*.sh
tests/
CI-TESTING.md
.github/

# Ignore large user directories that shouldn't be managed by chezmoi
Library/**
Music/**
Pictures/**
Movies/**
Documents/**
Downloads/**
Desktop/**
Developer/**
Applications/**
Public/**

# Ignore macOS system files
.DS_Store
.localized
.Trash/**

# Ignore application data
.cache/**
.npm/**
.node_modules/**
.bundle/**
```

- [ ] **Step 3: Update `.chezmoiignore.tmpl`**

The file has unstaged changes adding Windows OS guard blocks with `run_*` filename entries. Stage those changes but also remove the specific `run_*` filename entries from both OS guard blocks. The final `.chezmoiignore.tmpl` should be:

```
# Skip 1Password-dependent files when op CLI is not available (CI or no 1Password installed)
{{- if or (not .has1password) (env "CI") (env "GITHUB_ACTIONS") (env "GITLAB_CI") }}
.aws/config
.gitconfig
{{ end -}}

# Skip non-Windows files on Windows
{{- if eq .chezmoi.os "windows" }}
.config/fish
.config/tmux
.config/alacritty
.config/bash
.config/zsh
.config/shell
.bashrc
.zshrc
{{ end -}}

# Skip Windows-only files on non-Windows
{{- if ne .chezmoi.os "windows" }}
.config/powershell
{{ end -}}
```

- [ ] **Step 4: Stage and track remaining untracked files**

The `dot_config/scoopfile` is untracked — add it to git:

```bash
git add dot_config/scoopfile
```

Check `.gitignore` diff to see what changed, stage it too:

```bash
git add .gitignore
```

- [ ] **Step 5: Verify `chezmoi status` shows no unexpected changes**

```bash
chezmoi status
```

Expected: only dotfile changes (none, or expected updates from templates). No run script errors.

- [ ] **Step 6: Commit everything**

```bash
git add .chezmoiignore .chezmoiignore.tmpl
git commit -m "feat: move install scripts to scripts/, remove run_* from chezmoi"
```

---

### Task 9: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the Quick Start section**

The current "Bootstrap Process" and "What happens during bootstrap" sections reference `run_*` scripts by name and describe chezmoi phases that no longer apply. Replace the entire "Quick Start" section (from `## Quick Start` down to, but not including, `## Repository Structure`) with:

```markdown
## Quick Start

### New machine (full setup)

On macOS, install Xcode command line tools first:

```sh
xcode-select --install
```

Then bootstrap chezmoi (this clones the repo and applies dotfiles only):

```sh
BINDIR="$HOME/.local/bin" sh -c "$(curl -fsLS get.chezmoi.io)" -- init --ssh --apply jesserobertson
```

Then run installs:

```sh
make bootstrap   # installs prereqs + all tools
```

Or selectively:

```sh
make prereqs     # Homebrew (macOS/Linux) or Scoop (Windows)
make brew        # Homebrew packages from Brewfile
make rust        # Rust toolchain (stable + nightly)
make crates      # Rust crates from cratefile
make python      # Python tools via pixi
make skills      # Claude Code skills
make mcp         # MCP servers (macOS only)
make pixi        # pixi global packages
make tmux        # tmux plugin manager
make powershell  # PowerShell $PROFILE wrapper (Windows)
```

### Dotfiles only

```sh
chezmoi apply
```

### Day-to-day updates

```sh
chezmoi apply    # re-applies any changed templates
```
```

- [ ] **Step 2: Update the "File Naming Conventions" section**

Remove the four bullets that describe `run_before_`, `run_after_`, and `run_onchange_after_` prefixes (they no longer exist in this repo). Keep `dot_`, `private_`, `executable_`, and `.tmpl` bullets.

- [ ] **Step 3: Update the directory tree in "Directory Structure"**

Remove the `run_*` entries from the tree and add:

```
├── Makefile                          # Optional install targets
├── scripts/                          # Install scripts (run manually via make)
│   ├── install-prereqs.sh            # Homebrew + 1Password (macOS/Linux)
│   ├── install-prereqs.ps1           # Scoop + tools (Windows)
│   ├── install-brew.sh               # brew bundle install
│   ├── install-rust.fish             # rustup + toolchains
│   ├── install-crates.fish           # cargo install from cratefile
│   ├── install-python.fish           # pixi global sync
│   ├── install-skills.fish           # Claude Code skills
│   ├── install-mcp-servers.fish      # MCP servers (macOS)
│   ├── install-pixi.sh               # pixi global install
│   ├── update-tmux.sh                # TPM install
│   └── setup-powershell.ps1          # $PROFILE wrapper (Windows)
```

- [ ] **Step 4: Update "Adding New Packages" entries that say "chezmoi apply will trigger re-installation"**

These are no longer true since run scripts are gone. Change each one to:

- Homebrew: `make brew`
- Rust crates: `make crates`
- Python/pixi: `make python`
- Fish plugins: `chezmoi apply` (fisher update is not a make target — leave as-is)

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update README for scripts/ + Makefile, remove run_* references"
```

---

### Task 10: Final verification

- [ ] **Step 1: Confirm no run_* files remain in repo root**

```bash
ls run_* 2>&1
```

Expected: `ls: cannot access 'run_*': No such file or directory` (or equivalent "no such file" error).

- [ ] **Step 2: Confirm Makefile targets all resolve**

```bash
make -n bootstrap
make -n dotfiles
make -n brew
make -n rust
```

Expected: each prints the command it would run, no errors.

- [ ] **Step 3: Confirm chezmoi applies cleanly**

```bash
chezmoi apply --dry-run
```

Expected: output shows dotfile changes only — no script execution errors.

- [ ] **Step 4: Final commit if anything remains unstaged**

```bash
git status
```

If clean: done. If any files remain unstaged, stage and commit them.
