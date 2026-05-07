# dotfiles

Managing my dotfiles using chezmoi. Supports macOS (Intel/ARM), Linux, and Windows.

## Quick Start

### New machine — Windows

winget is the only prerequisite (built into Windows 11).

**1. Install chezmoi:**
```powershell
winget install twpayne.chezmoi
```

**2. Apply dotfiles (also bootstraps scoop and installs scoop packages):**
```powershell
chezmoi init --ssh --apply jesserobertson
```

**3. Install remaining winget packages (Git, Go, VSCode, etc.):**
```powershell
make prereqs
```

**4. Set up the PowerShell profile wrapper:**
```powershell
make powershell
```

---

### New machine — macOS / Linux

On macOS, install Xcode command line tools first:

```sh
xcode-select --install
```

Install chezmoi and apply dotfiles:

```sh
BINDIR="$HOME/.local/bin" sh -c "$(curl -fsLS get.chezmoi.io)" -- init --ssh --apply jesserobertson
```

Then install all tools:

```sh
make bootstrap   # installs prereqs + all tools
```

Or selectively:

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
├── chezmoi.toml                      # Main configuration with template variables
├── .chezmoiignore                    # Files to ignore when applying
├── .chezmoitemplates/                # Shared template functions
├── LICENSE                           # MIT License
├── README.md                         # This file
│
├── Shell configurations
├── dot_bashrc.tmpl                   # Bash shell configuration (templated)
├── dot_zshrc.tmpl                    # Zsh shell configuration (templated)
├── dot_editorconfig                  # EditorConfig settings
├── dot_gitconfig.tmpl                # Git config (1Password integrated)
│
├── Makefile                          # Optional install targets
├── scripts/                          # Install scripts (run manually via make)
│   ├── install-prereqs.sh            # Homebrew + 1Password (macOS/Linux)
│   ├── install-prereqs.ps1           # winget packages (Windows, run before chezmoi apply)
│   ├── install-brew.sh               # brew bundle install
│   ├── install-rust.fish             # rustup + toolchains
│   ├── install-crates.fish           # cargo install from cratefile
│   ├── install-python.fish           # pixi global sync
│   ├── install-skills.fish           # Claude Code skills
│   ├── install-mcp-servers.fish      # MCP servers (macOS)
│   ├── install-pixi.sh               # pixi global install
│   ├── update-tmux.sh                # TPM install
│   └── setup-powershell.ps1          # $PROFILE wrapper (Windows)
│
├── Application configurations
├── dot_config/
│   ├── alacritty/                    # Terminal emulator (145+ themes)
│   ├── bat/                          # Syntax highlighter configuration
│   ├── brewfile.tmpl                 # Homebrew package definitions
│   ├── cratefile                     # Rust crate definitions
│   ├── haskellfile                   # Haskell package definitions
│   ├── executable_start-terminal.sh.tmpl  # Terminal startup script
│   ├── fish/                         # Fish shell (119 functions, 9 completions)
│   ├── nvim/                         # Neovim LazyVim configuration
│   ├── sesh/                         # Tmux session manager
│   ├── shell/                        # Shared shell environment variables
│   ├── starship.toml                 # Starship prompt configuration
│   └── tmux/                         # Tmux modular configuration
│       ├── tmux.conf                 # Main config (loads others)
│       ├── conf.d/                   # Modular config files
│       ├── scripts/                  # Utility scripts
│       └── themes/                   # Theme files
│
├── Python environment
├── private_dot_pixi/
│   └── manifests/
│       └── pixi-global.toml.tmpl     # Pixi global manifest
│
├── Private configurations
├── private_dot_aws/                  # AWS CLI configuration (private)
│
├── Claude Code settings
├── .claude/                          # Local settings
└── dot_claude/                       # User settings
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
editor = "nvim"
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

### Homebrew (Primary Package Manager)

Manages system packages, GUI applications, and programming languages:

- **Programming languages**: Node.js, Go, Rust (rustup), Julia (juliaup)
- **Core CLI tools**: bat, eza, fd, fzf, ripgrep, chezmoi, direnv, fish, git
- **Development tools**: awscli, gcloud, jq, neovim, pixi, terraform, packer
- **Desktop applications**: Alacritty, Claude Code, Raycast (macOS only)
- **Fonts**: Fira Code, Fira Code Nerd Font, Fira Mono Nerd Font
- **System dependencies**: coreutils, gnupg, openssl

**Managed via**: `dot_config/brewfile.tmpl` (30 brews, 6 casks, 4 fonts)

### Cargo (Rust Crates)

Installs Rust-based CLI tools with pinned versions:

- **Terminal tools**: alacritty, starship, zoxide
- **File utilities**: bat, eza, fd-find, ripgrep
- **Git tools**: git-delta, gitui
- **Development**: tokei, cargo-watch, cargo-edit

**Managed via**: `dot_config/cratefile` (21 crates)

### Pixi (Python Global Packages)

Manages global Python tools via conda-forge in isolated environments:

- **Development tools**: ipython, jupyter, jupyterlab, marimo
- **Linters/formatters**: ruff, mypy
- **Language servers**: pyright

**Managed via**: `private_dot_pixi/manifests/pixi-global.toml.tmpl` (8 packages in python environment)

All packages are installed in `~/.pixi/bin` and automatically added to PATH. The manifest is native pixi format and synced automatically when changes are detected.

### Cabal (Haskell Packages)

Installs Haskell libraries globally:

- **Live coding**: tidal (TidalCycles for music)

**Managed via**: `dot_config/haskellfile` (1 package)

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
- **Common**: `dot_config/shell/dot_common_env.sh.tmpl` (shared across shells)

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
Edit `dot_config/brewfile.tmpl` and run:
```sh
make brew
```

**Rust crates:**
Edit `dot_config/cratefile` and run:
```sh
make crates
```

**Python packages (via pixi):**
Edit `~/.pixi/manifests/pixi-global.toml` and run:
```sh
make python
```

**Haskell packages:**
Edit `dot_config/haskellfile` and run:
```sh
$ chezmoi apply
```

**Fish plugins:**
Edit `dot_config/fish/fish_plugins` and run:
```sh
$ chezmoi apply
```

## Testing

### Docker-based Testing Framework

This repository includes a comprehensive Docker-based testing framework to validate the dotfiles setup across different platforms:

```sh
# Test Ubuntu environment
./tests/run-tests.sh --platforms ubuntu

# Test both Ubuntu and macOS-like environments
./tests/run-tests.sh --platforms ubuntu,macos

# Extended timeout with verbose output
./tests/run-tests.sh --platforms ubuntu,macos --timeout 900 --verbose
```

#### What Gets Tested

The testing framework validates:

- ✅ **Complete bootstrap process**: Full `chezmoi init --apply` workflow
- ✅ **Cross-platform Homebrew**: Linux Homebrew installation and configuration
- ✅ **Package installation**: All Brewfile packages install correctly
- ✅ **Dotfiles application**: Shell configs and application configs are applied
- ✅ **OS detection logic**: Platform-specific path handling works correctly
- ✅ **Core tools verification**: Essential CLI tools (git, fish, nvim, tmux, etc.)
- ✅ **Programming languages**: Go, Node.js, Rust installation
- ✅ **Development tools**: AWS CLI, gcloud, terraform, etc.

#### Test Architecture

```
tests/
├── run-tests.sh              # Main test runner with CLI options
├── verify-installation.sh    # Standalone verification script
├── test-shell-env.sh         # Shell environment tests
├── README.md                 # Detailed testing documentation
└── docker/
    ├── ubuntu/               # Ubuntu container tests
    │   ├── Dockerfile
    │   ├── test-bootstrap.sh           # Live GitHub test
    │   └── test-bootstrap-offline.sh   # Mock repository test
    └── macos/                # macOS-like container tests
        ├── Dockerfile
        ├── test-bootstrap-macos.sh
        └── test-bootstrap-offline.sh
```

#### Standalone Verification

You can also verify an existing installation on any system:

```sh
./tests/verify-installation.sh
```

This script performs comprehensive checks without requiring Docker and can be used to verify live installations.

#### CI/CD Integration

The Docker tests are designed for CI/CD pipelines:

- **Configurable timeouts**: Adjust for different CI environments
- **Parallel execution**: Test multiple platforms simultaneously
- **Detailed reporting**: Color-coded output with clear pass/fail indicators
- **Exit codes**: Proper exit codes for CI integration
- **Offline testing**: Mock repositories avoid external dependencies

See `tests/README.md` for detailed usage instructions and troubleshooting.

## Advanced Features

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
