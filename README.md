# dotfiles

Managing my dotfiles using chezmoi. Supports macOS (Intel/ARM), Linux, and Windows.

## Quick Start

### New machine — Windows

winget is the only prerequisite (built into Windows 11).

**1. Install chezmoi:**
```powershell
winget install twpayne.chezmoi
```

**2. Apply dotfiles and bootstrap tools (Scoop packages + PowerShell profile wired automatically):**
```powershell
chezmoi init --ssh --apply jesserobertson
```

---

### New machine — macOS / Linux

On macOS, install Xcode command line tools first:

```sh
xcode-select --install
```

Install chezmoi and apply dotfiles — this handles everything (Homebrew, packages, tools) automatically via `run_onchange_` scripts:

```sh
BINDIR="$HOME/.local/bin" sh -c "$(curl -fsLS get.chezmoi.io)" -- init --ssh --apply jesserobertson
```

Or run individual steps manually:

```sh
make prereqs     # Homebrew (macOS/Linux)
make brew        # Homebrew packages from Brewfile
make rust        # Rust toolchain (stable + nightly)
make crates      # Rust crates from cratefile
make python      # Python tools via pixi
make skills      # Claude Code skills
make mcp         # MCP servers (macOS only)
make pixi        # pixi global packages
make tmux        # tmux plugin manager
```

---

### Dotfiles only

```sh
chezmoi apply
```

### Day-to-day updates

```sh
chezmoi apply    # re-applies any changed templates
```

## Repository Structure

### File Naming Conventions

Chezmoi uses special prefixes to control how files are processed:

- **`dot_`** - Creates a dotfile (hidden file starting with `.`)
  - `dot_bashrc.tmpl` → `~/.bashrc`
  - `dot_config/` → `~/.config/`

- **`private_`** - Marks file as private (restrictive permissions)
  - `private_dot_aws/` → `~/.aws/` (with 700 permissions)
  - `private_alacritty.toml.tmpl` → `alacritty.toml` (with 600 permissions)

- **`executable_`** - Makes file executable
  - `executable_start-terminal.sh.tmpl` → `start-terminal.sh` (with +x)

- **`.tmpl`** - Template file (processed with Go templates)
  - Supports variables from `chezmoi.toml`
  - Enables conditional logic and platform detection

### Directory Structure

```
~/.local/share/chezmoi/
├── .chezmoi.toml.tmpl                # Template variables (editor, homebrew prefix, ssh agent, etc.)
├── .chezmoiignore.tmpl               # OS-conditional file exclusions
├── AGENTS.md                         # Repo context for AI agents
├── Makefile                          # Manual install targets (bootstrap = chezmoi apply)
│
├── run_before_00-install-prereqs.sh.tmpl         # Install Homebrew before dotfiles apply
├── run_onchange_after_00-install-brews.sh.tmpl   # brew bundle (re-runs when brewfile changes)
├── run_onchange_after_01-install-rust.fish.tmpl  # rustup + stable/nightly
├── run_onchange_after_02-install-crates.fish.tmpl # cargo install (re-runs when cratefile changes)
├── run_onchange_after_03-install-pixi.sh.tmpl    # pixi global install
├── run_onchange_after_04-install-skills.fish.tmpl # Claude Code skills
├── run_onchange_after_05-install-mcp-servers.fish.tmpl # MCP setup (macOS only)
├── run_once_after_06-install-tmux-plugins.sh.tmpl # TPM install (once)
├── run_onchange_after_07-setup-powershell.ps1    # Wire $PROFILE (Windows only)
├── run_onchange_windows_install-packages.ps1.tmpl # Scoop + cargo crates (Windows only)
│
├── dot_bashrc.tmpl                   # Bash config
├── dot_zshrc.tmpl                    # Zsh config
├── dot_editorconfig                  # EditorConfig settings
├── dot_gitconfig.tmpl                # Git config (1Password integrated)
│
├── packages/                         # Package definition files
│   ├── brewfile.tmpl                 # Homebrew packages (cross-platform + macOS-only)
│   ├── cratefile                     # Rust crates
│   ├── haskellfile                   # Haskell packages
│   ├── scoopfile                     # Scoop packages (Windows)
│   └── wingetfile                    # Winget packages (Windows)
│
├── scripts/                          # Manual fallbacks (called by run_onchange_ scripts above)
│   ├── install-prereqs.sh            # Homebrew + 1Password (macOS/Linux)
│   ├── install-prereqs.ps1           # Winget bootstrap (Windows)
│   ├── install-brew.sh               # brew bundle install
│   ├── install-rust.fish             # rustup + toolchains
│   ├── install-crates.fish           # cargo install from cratefile
│   ├── install-crates.ps1            # cargo install (Windows)
│   ├── install-pixi.sh               # pixi global install
│   ├── install-skills.fish           # Claude Code skills
│   ├── install-mcp-servers.fish      # MCP servers (macOS)
│   ├── install-winget-packages.ps1   # Bulk winget install (Windows)
│   └── update-tmux.sh                # TPM install
│
├── dot_config/
│   ├── fish/                         # Fish shell config and functions
│   ├── bash/                         # Bash-specific config
│   ├── zsh/                          # Zsh-specific config
│   ├── shell/                        # Shared POSIX env vars (sourced by bash/zsh)
│   ├── powershell/                   # PowerShell profile and functions (Windows)
│   ├── alacritty/                    # Terminal emulator
│   ├── bat/                          # Syntax highlighter
│   ├── nvim/                         # Neovim configuration
│   ├── tmux/                         # Tmux config
│   ├── sesh/                         # Tmux session manager
│   ├── starship.toml                 # Starship prompt
│   └── executable_start-terminal.sh.tmpl
│
└── private_dot_aws/                  # AWS CLI config (private permissions)
```

## Template System

### Data Sources

The `chezmoi.toml` file provides variables to all templates:

**Platform Detection:**
```toml
osid = "darwin"  # or "linux-ubuntu"
```

**XDG Directory Structure:**
```toml
xdg_config_home = "~/.config"
xdg_data_home = "~/.local/share"
xdg_cache_home = "~/.cache"
xdg_state_home = "~/.local/state"
```

**Homebrew Paths (OS-aware):**
```toml
homebrew_prefix = "/opt/homebrew"              # ARM Mac
                # "/usr/local"                  # Intel Mac
                # "/home/linuxbrew/.linuxbrew"  # Linux
```

**Tool Configuration:**
```toml
editor = "hx"
pager = "less"
git_pager = "delta"
cargo_home = "~/.local/share/cargo"
rustup_home = "~/.local/share/rustup"
cabal_home = "~/.cabal"
pixi_home = "~/.pixi"
```

### Template Usage

**Environment Variables:**
```bash
export XDG_CONFIG_HOME="{{ .xdg_config_home }}"
export CARGO_HOME="{{ .cargo_home }}"
```

**Conditional Logic:**
```ruby
{{ if eq .chezmoi.os "darwin" }}
cask "claude-code"
{{ end }}
```

**1Password Integration:**
```gitconfig
{{- onepasswordDocument "document-id" -}}
```

## Tool Installation Strategy

This dotfiles setup uses a multi-layered package management approach:

### Light vs. Heavy Installs

Not every package installs by default. Three tiers, controlled by two
environment variables (set before running `chezmoi apply`/`chezmoi init`):

| Tier | Packages | Default behavior | Controlled by |
|------|----------|-------------------|----------------|
| **Core** | Shell/dev essentials — `bat`, `chezmoi`, `direnv`, `eza`, `fd`, `fish`, `fzf`, `git`, `git-delta`, `gh`, `jq`, `just`, `neovim`, `pixi`, `ripgrep`, `starship`, `tmux`, `zoxide`, etc. (Windows equivalents via scoop: `starship`, `zoxide`, `fzf`, `ripgrep`, `fd`, `bat`, `delta`, `yq`, `helix`, `gh`, `aws`, `pixi`, ...) | Always installed | — |
| **Heavy CLI tools** | `awscli`, `bats-core`, `cmake`, `coreutils`, `git-flow`, `gnupg`, `htop`, `juliaup`, `llm`, `openjdk`, `pandoc`, `roborev` | Installed on a real machine; skipped in Docker containers or CI | `HOMEBREW_SKIP_HEAVY=1` to skip (CI-only knob — you shouldn't need this) |
| **Heavy toolchains** | `llvm`, `nodejs`, `golang`, `ghcup`, `rustup` | Skipped everywhere by default, even on a real machine, since they're slow and not always needed right after a fresh apply | `DOTFILES_FULL_INSTALL=1` to install |

```sh
DOTFILES_FULL_INSTALL=1 chezmoi apply          # Linux/macOS: install everything, including heavy toolchains
```
```powershell
$env:DOTFILES_FULL_INSTALL = "1"; chezmoi init --apply jesserobertson   # Windows
```

chezmoi doesn't support custom CLI flags on `init`/`apply`, so this is an
environment variable rather than a literal `--full-install` flag. `pixi` is
always installed regardless of tier, since several other scripts depend on it.

macOS GUI casks (Raycast, Chromium, Anki, Ghostty, fonts, etc.) are a fourth,
separate concern — they install on a real machine but are always skipped in
CI, independent of the flags above.

### Homebrew (Primary Package Manager)

Manages system packages, GUI applications, and programming languages:

- **Programming languages**: Node.js, Go, Rust (rustup), LLVM/GHC (ghcup) — heavy toolchains, opt-in via `DOTFILES_FULL_INSTALL=1` (see [Light vs. Heavy Installs](#light-vs-heavy-installs)); Julia (juliaup) installs by default
- **Core CLI tools**: bat, eza, fd, fzf, ripgrep, chezmoi, direnv, fish, git
- **Development tools**: awscli, gcloud, jq, neovim, pixi, terraform, packer
- **Desktop applications**: Alacritty, Claude Code, Raycast (macOS only)
- **Fonts**: Fira Code, Fira Code Nerd Font, Fira Mono Nerd Font
- **System dependencies**: coreutils, gnupg, openssl

**Managed via**: `packages/brewfile.tmpl` (cross-platform brews + macOS-only casks/fonts)

### Cargo (Rust Crates)

Installs Rust-based CLI tools with pinned versions:

- **Terminal tools**: alacritty, starship, zoxide
- **File utilities**: bat, eza, fd-find, ripgrep
- **Git tools**: git-delta, gitui
- **Development**: tokei, cargo-watch, cargo-edit

**Managed via**: `packages/cratefile`

### Pixi (Python Global Packages)

Manages global Python tools via conda-forge in isolated environments:

- **python env**: python, uv, ruff, mypy
- **requests env**: requests

**Managed via**: `scripts/install-pixi.sh` (run automatically on `chezmoi apply` via `run_onchange_after_03`)

All packages are installed in `~/.pixi/bin` and automatically added to PATH.

### Cabal (Haskell Packages)

Installs Haskell libraries globally:

- **Live coding**: tidal (TidalCycles for music)

**Managed via**: `packages/haskellfile`

### Fisher (Fish Shell Plugins)

Manages Fish shell plugins:

- **z**: Autojump to frequently used directories
- **gitnow**: Git workflow shortcuts
- **puffer-fish**: Text expansion for Fish

**Managed via**: `dot_config/fish/fish_plugins`

### Configuration Areas

#### Shell Configuration

- **Fish** (Primary shell): 119 custom functions, 9 completions
  - Git operations, project management, system utilities, text processing
- **Bash/Zsh**: Templated configs using shared environment variables
- **Common**: `dot_config/shell/env.sh.tmpl` (shared POSIX env vars sourced by bash/zsh)

#### Development Tools

- **Neovim**: LazyVim-based configuration with custom language support
- **Tmux**: Modular configuration split across `conf.d/` for maintainability
- **Git**: 1Password-integrated configuration for secure credential management
- **Starship**: Customized prompt with extensive icon configuration

#### Terminal & UI

- **Alacritty**: Private templated config with 145+ color themes
- **Tmux**: Modular configuration with TPM plugin management
- **Sesh**: Session manager with predefined workspace layouts

## Platform-Specific Features

### macOS vs Linux Handling

**Homebrew Prefix Detection:**
- Apple Silicon Mac: `/opt/homebrew`
- Intel Mac: `/usr/local`
- Linux: `/home/linuxbrew/.linuxbrew`

**Platform-Specific Packages:**
```ruby
{{ if eq .chezmoi.os "darwin" }}
cask "1password-cli"
cask "claude-code"
cask "raycast"
{{ end }}
```

**Architecture Detection:**
Automatically detects ARM vs x86_64 and adjusts paths accordingly.

## Design Principles

- **Homebrew-centric**: Use Homebrew for all package management to simplify dependencies
- **Template-driven**: Single source of truth (`chezmoi.toml`) drives all configurations
- **Cross-platform**: Same repository works on macOS (Intel/ARM) and Linux
- **Security-focused**: Private files, 1Password integration, proper permissions
- **Modular**: Configurations split into logical, maintainable pieces
- **XDG-compliant**: Follows XDG Base Directory specification
- **Testable**: Comprehensive Docker-based testing ensures reliability

## Maintenance

### Clean Installation Reset

The `chezmoi-cleanup` fish function provides a comprehensive cleanup of all tool caches and data directories:

```sh
$ chezmoi-cleanup
```

This command will:
1. Remove history files (bash, zsh, fish, vim, less)
2. Clean temporary files (.DS_Store, temp files in Downloads/Desktop/cache)
3. Remove application data directories (nvim, alacritty, bat, fish, tmux, starship, chezmoi)
4. Clean package manager caches (Homebrew, Cargo, npm, pixi, Fisher)
5. Clean log directories

After cleanup, run `chezmoi apply` to restore your dotfiles and restart your terminal.

### Updating Configurations

To update your dotfiles after making changes:

```sh
# Edit files in the chezmoi source directory
$ chezmoi edit ~/.bashrc

# Or edit directly and add changes
$ vi ~/.config/fish/config.fish
$ chezmoi add ~/.config/fish/config.fish

# Apply changes
$ chezmoi apply

# Review changes before applying
$ chezmoi diff
```

### Adding New Packages

**Homebrew packages:**
Edit `packages/brewfile.tmpl` and run:
```sh
make brew
```

**Rust crates:**
Edit `packages/cratefile` and run:
```sh
make crates
```

**Python packages (via pixi):**
Edit `~/.pixi/manifests/pixi-global.toml` and run:
```sh
make python
```

**Haskell packages:**
Edit `packages/haskellfile` and run:
```sh
$ chezmoi apply
```

**Fish plugins:**
Edit `dot_config/fish/fish_plugins` and run:
```sh
$ chezmoi apply
```

## Testing

### Running Tests

**Windows (Pester unit tests + chezmoi dry-run):**
```powershell
$env:CI = "true"; chezmoi init --source="$PWD" --apply --dry-run
Invoke-Pester tests/powershell
```

**Linux (Docker):**
```sh
bash tests/docker/ubuntu/test-bootstrap.sh       # full bootstrap
bash tests/docker/ubuntu/test-bootstrap-offline.sh  # offline/mock
```

**bats shell tests (after install):**
```sh
bats tests/bats/install.bats tests/bats/shell-env.bats tests/bats/fish.bats
```

**Template validation (any platform):**
```sh
chezmoi init --source="$PWD"   # needed once so template vars are available
chezmoi execute-template < dot_bashrc.tmpl
chezmoi execute-template < dot_zshrc.tmpl
chezmoi execute-template < dot_config/fish/env.fish.tmpl
chezmoi execute-template < packages/brewfile.tmpl
```

### What Gets Tested

The testing framework validates the **two-step setup** (dotfiles first, then tools):

- ✅ **Dotfiles application**: `chezmoi init --apply` applies shell configs correctly
- ✅ **Prerequisites**: `scripts/install-prereqs.sh` installs Homebrew (Linux/macOS)
- ✅ **Package installation**: `scripts/install-brew.sh` installs all Brewfile packages
- ✅ **Cross-platform Homebrew**: Linux (`/home/linuxbrew`) vs macOS (`/opt/homebrew`) paths
- ✅ **Core tools**: git, fish, jq, tmux, fzf, bat, etc.
- ✅ **OS detection**: Platform-specific path handling
- ✅ **Windows**: Pester tests for PowerShell functions, chezmoi dry-run

These are smoke tests: Windows only does a `--dry-run` and macOS/Ubuntu skip
heavy packages, so they can't catch bugs that only surface when scripts
actually execute for real. Once these smoke tests pass, `full-install-ubuntu`,
`full-install-macos`, and `full-install-windows` run a real, undiluted
`chezmoi init --apply` (with `DOTFILES_FULL_INSTALL=1`) on each platform.

### Test Architecture

```
tests/
├── verify-installation.sh        # Standalone verification (any system)
├── test-shell-env.sh             # Shell environment consistency tests
├── bats/                         # bats-core shell tests
│   ├── install.bats              # Tool install checks
│   ├── shell-env.bats            # EDITOR/PAGER/PATH consistency across bash/zsh/fish
│   ├── fish.bats                 # Fish-specific startup and config tests
│   └── helpers/                  # brew env setup, bats-support/assert loaders
├── powershell/                   # Pester unit tests (Windows)
│   └── functions.Tests.ps1
└── docker/
    └── ubuntu/
        ├── Dockerfile
        ├── test-bootstrap.sh           # Online: chezmoi apply + run_onchange_ scripts
        └── test-bootstrap-offline.sh   # Offline: mock repo, dotfiles only
```

### Standalone Verification

On any system after install:
```sh
./tests/verify-installation.sh
```

Checks Homebrew, installed packages (via `packages/brewfile.tmpl`), dotfiles, and shell environment consistency.

## Advanced Features

### Cached Shell Tool Initialization

Shell tool init scripts (`starship init`, `zoxide init`, `direnv hook`, `fzf --fish`, etc.) are cached by binary mtime so they only run once per tool upgrade, not on every shell startup. This mirrors the PowerShell profile pattern for starship.

**Fish** — shared helper in `dot_config/fish/functions/init_cached.fish`:
```fish
init_cached starship starship init fish   # cached to ~/.cache/fish/starship_init_<mtime>.fish
init_cached zoxide   zoxide init fish
init_cached direnv   direnv hook fish
# ...etc
```

**Bash / Zsh** — `_init_cached` helper defined inline in `.bashrc`/`.zshrc`:
```bash
_init_cached fzf      fzf --bash          # cached to ~/.cache/bash/fzf_init_<mtime>.bash
_init_cached starship starship init bash
_init_cached zoxide   zoxide init bash
# ...etc
```

Cache files live under `$XDG_CACHE_HOME/{bash,zsh,fish}/` and are invalidated automatically when the binary changes.

### Safe PATH Management

Bash/Zsh configurations use `safe_add_path()` to avoid PATH pollution:

```bash
safe_add_path() {
    local dir="$1"
    if [ -d "$dir" ] && [ -r "$dir" ]; then
        case ":$PATH:" in
            *":$dir:"*) ;;  # Skip if already in PATH
            *) export PATH="$dir:$PATH" ;;
        esac
    fi
}
```

### Terminal Startup Chain

`start-terminal.sh` implements intelligent fallback:

```
sesh (session manager) → tmux → fish → zsh
```

This ensures a consistent terminal experience with session management.

### 1Password Integration

Sensitive configurations are stored in 1Password and fetched during template processing:

```gitconfig
{{- onepasswordDocument "e5h22omqx7y47iw4ln3dkxjicy" -}}
```

This keeps secrets out of version control while maintaining reproducibility.

## Troubleshooting

### Homebrew Installation Fails

If Homebrew installation fails on Linux:
```sh
# Manually install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Then rerun chezmoi
chezmoi apply
```

### Template Processing Errors

If you encounter template errors:
```sh
# Validate template syntax
chezmoi execute-template < dot_bashrc.tmpl

# Check available template data
chezmoi data
```

### Permission Errors

If you see permission errors:
```sh
# Fix ownership
sudo chown -R $(whoami) ~/.local/share/chezmoi

# Reapply with verbose output
chezmoi apply -v
```

## License

MIT License - see [LICENSE](LICENSE) file for details.
