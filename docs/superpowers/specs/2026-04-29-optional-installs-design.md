# Optional Installs + Public Repo Design

**Date:** 2026-04-29  
**Status:** Approved

## Goal

Separate install scripts from dotfile management so that `chezmoi apply` only manages dotfiles (config files, shell configs, etc.) and tool installation is explicitly opt-in via a `Makefile`.

Secondary goal: confirm the repo is safe to make public (no secrets in history or current files).

---

## Current State

Ten `run_*` scripts live in the chezmoi source directory:

| Script | Purpose |
|---|---|
| `run_before_00-install-prereqs.sh.tmpl` | Install Homebrew + 1Password CLI (macOS/Linux) |
| `run_before_00-install-prereqs.ps1` | Install Scoop, 1Password CLI, oh-my-posh (Windows) |
| `run_after_00-install-brews.sh.tmpl` | `brew bundle install` from Brewfile |
| `run_onchange_after_01-install-rust.fish.tmpl` | rustup + stable + nightly toolchains |
| `run_onchange_after_02-install-crates.fish.tmpl` | `cargo install` from Crates file |
| `run_onchange_after_03-install-python.fish.tmpl` | Python via pixi |
| `run_onchange_after_04-install-skills.fish.tmpl` | Claude Code skills |
| `run_onchange_after_05-install-mcp-servers.fish.tmpl` | MCP server installs |
| `run_onchange_after_06-setup-powershell.ps1` | Write `$PROFILE` wrapper (Windows) |
| `run_onchange_install-pixi-global.sh.tmpl` | pixi global packages |
| `run_after_04-update-tmux.bash.tmpl` | tmux plugin manager update |

These scripts use chezmoi template variables (e.g., `{{ .rustup_home }}`, `{{ .xdg_config_home }}`).

The static `.chezmoiignore` currently lists `run_*` which prevents chezmoi from executing them, but this is implicit and fragile.

---

## Design

### File Structure

Move all run scripts into a `scripts/` directory with readable names, removing chezmoi execution prefixes:

```
scripts/
  install-prereqs.sh         ← run_before_00-install-prereqs.sh.tmpl
  install-prereqs.ps1        ← run_before_00-install-prereqs.ps1
  install-brew.sh            ← run_after_00-install-brews.sh.tmpl
  install-rust.fish          ← run_onchange_after_01-install-rust.fish.tmpl
  install-crates.fish        ← run_onchange_after_02-install-crates.fish.tmpl
  install-python.fish        ← run_onchange_after_03-install-python.fish.tmpl
  install-skills.fish        ← run_onchange_after_04-install-skills.fish.tmpl
  install-mcp-servers.fish   ← run_onchange_after_05-install-mcp-servers.fish.tmpl
  setup-powershell.ps1       ← run_onchange_after_06-setup-powershell.ps1
  install-pixi.sh            ← run_onchange_install-pixi-global.sh.tmpl
  update-tmux.sh             ← run_after_04-update-tmux.bash.tmpl
Makefile
```

Chezmoi ignores `scripts/` and `Makefile` automatically — they use no chezmoi naming conventions, so no `.chezmoiignore` changes are needed.

### Template Variable Migration

Scripts that use chezmoi template syntax (`.tmpl` files) get the `.tmpl` suffix removed and template variables replaced with environment variable references with sensible defaults:

| Template var | Replacement |
|---|---|
| `{{ .rustup_home }}` | `${RUSTUP_HOME:-$HOME/.local/share/rustup}` |
| `{{ .cargo_home }}` | `${CARGO_HOME:-$HOME/.local/share/cargo}` |
| `{{ .xdg_config_home }}` | `${XDG_CONFIG_HOME:-$HOME/.config}` |
| `{{ .pixi_home }}` | `${PIXI_HOME:-$HOME/.pixi}` |

Fish scripts already `source ~/.config/fish/env.fish` so they pick up the correct values from the deployed dotfiles at runtime. The `{{- if hasKey .chezmoi "force" }}` blocks are replaced with a simple `${FORCE:-false}` env var check.

The OS guard `{{- if ne .chezmoi.os "windows" -}}` wrappers are replaced with inline `uname -s` checks or removed where the script is already platform-specific by filename.

### Makefile Targets

```makefile
.PHONY: bootstrap dotfiles prereqs brew rust crates python skills mcp pixi tmux powershell

# Full new-machine setup
bootstrap: dotfiles prereqs brew rust crates python skills mcp pixi

# Dotfiles only — the everyday command
dotfiles:
    chezmoi apply

# Prerequisites: Homebrew (macOS/Linux) or Scoop (Windows)
prereqs:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        powershell -ExecutionPolicy Bypass -File scripts/install-prereqs.ps1; \
    else \
        bash scripts/install-prereqs.sh; \
    fi

brew:        ## Install Homebrew packages from Brewfile
    bash scripts/install-brew.sh

rust:        ## Install Rust toolchain via rustup
    fish scripts/install-rust.fish

crates:      ## Install Rust crates
    fish scripts/install-crates.fish

python:      ## Set up Python via pixi
    fish scripts/install-python.fish

skills:      ## Install Claude Code skills
    fish scripts/install-skills.fish

mcp:         ## Install MCP servers
    fish scripts/install-mcp-servers.fish

pixi:        ## Install pixi global packages
    bash scripts/install-pixi.sh

tmux:        ## Update tmux plugins
    bash scripts/update-tmux.sh

powershell:  ## Write PowerShell $PROFILE wrapper (Windows)
    powershell -ExecutionPolicy Bypass -File scripts/setup-powershell.ps1
```

### Public Repo Readiness

The repo is clean. Git history contains no secrets:
- `dot_gitconfig.tmpl` and `private_dot_aws/config.tmpl` use 1Password document IDs — references only, never the actual content
- A previously deleted `.claude/settings.local.json` contained only Claude Code permission paths, not credentials
- No API keys, tokens, passwords, or SSH private keys found in any commit

The author email (`jess.robertson@niwa.co.nz`) appears in commit author fields throughout history — inherent to git, acceptable for a personal dotfiles repo.

### README Updates

Add a **Usage** section to `README.md`:

```
## Usage

### Dotfiles only
chezmoi apply

### New machine setup
make bootstrap

### Individual installs
make brew          # Homebrew packages
make rust          # Rust toolchain
make crates        # Rust crates
make python        # Python (pixi)
make skills        # Claude Code skills
make mcp           # MCP servers
make pixi          # pixi globals
make tmux          # tmux plugins
make powershell    # PowerShell profile (Windows)
```

---

## What Does NOT Change

- Chezmoi manages all dotfiles exactly as before
- `.chezmoiignore.tmpl` OS-specific exclusions remain unchanged
- The `dot_config/scoopfile` Windows package list stays as a reference file

---

## Migration Steps

1. Create `scripts/` directory
2. For each `run_*` script: copy to `scripts/<name>`, strip `.tmpl` suffix if present, replace template vars with env var equivalents, replace OS guards with inline checks
3. Add `Makefile`
4. Delete all `run_*` files from the chezmoi source directory
5. Clean up `run_*` entry from static `.chezmoiignore` (no longer needed), and remove stale `run_*` filename references from `.chezmoiignore.tmpl` OS guard blocks
6. Update `README.md` with usage instructions
7. Commit and push; make GitHub repo public
