# dotfiles
Managing my dotfiles using chezmoi and homebrew

## Bootstrap Process

Bootstrap a new install - first install xcode-select tools to get the basics:

```sh
$ xcode-select --install
```

Then bootstrap chezmoi using the following command. This will clone the dotfiles repository and automatically run the installation scripts:

```sh
$ BINDIR="$HOME/.local/bin" sh -c "$(curl -fsLS get.chezmoi.io)" -- init --ssh --apply jesserobertson
```

### What happens during bootstrap:

1. **Apply dotfiles**: Chezmoi copies all configuration files to their proper locations
2. **Post-install Brewfile** (`run_after_Brewfile.sh.tmpl`): Installs Homebrew if not present, then installs all packages from `Brewfile`
3. **Post-install cleanup** (`run_after_install.fish`): Updates Fish shell plugins and performs cleanup

## Tool Installation Strategy

This dotfiles setup uses Homebrew as the primary package manager for all tools:

### Homebrew
- **Programming languages**: Node.js, Go (via golang), Rust (via rustup), Julia (via juliaup)
- **Core CLI tools**: Essential command-line utilities (bat, eza, fd, fzf, ripgrep, etc.)
- **Development tools**: awscli, gcloud, jq, neovim, pixi, terraform, packer
- **Desktop applications**: GUI applications and casks (Alacritty, Claude Code, Raycast)
- **Fonts**: Programming fonts including Fira Code and Nerd Fonts
- **System dependencies**: Base tools like git, gnupg, openssl

**Managed via**: `Brewfile` with packages installed during bootstrap

### Configuration Management

All configuration files are managed by chezmoi with the following structure:

```
├── Homebrew packages (Brewfile)
│   ├── Languages: golang, nodejs, rustup, juliaup
│   ├── CLI tools: bat, chezmoi, direnv, eza, fd, fzf, git, ripgrep, etc.
│   ├── Development tools: awscli, gcloud, jq, neovim, pixi, terraform
│   ├── Desktop apps: alacritty, claude-code, raycast, vagrant
│   └── Fonts: fira-code, fira-code-nerd-font, fira-mono-nerd-font
└── Configuration files
    ├── Shell config: dot_zshrc, dot_bashrc
    ├── Development: dot_editorconfig
    ├── Application configs: dot_config/
    │   ├── alacritty/ (terminal emulator)
    │   ├── bat/ (syntax highlighting)
    │   ├── fish/ (shell configuration)
    │   ├── nvim/ (neovim configuration)
    │   ├── tmux/ (terminal multiplexer)
    │   └── starship.toml (shell prompt)
    ├── Cloud configs: private_dot_aws/
    └── Ignore patterns: .chezmoiignore
```

## Design Principles

- **Homebrew-only**: Use Homebrew for all package management to simplify dependencies
- **Centralized configuration**: All configs managed through chezmoi templates
- **Automated setup**: Full environment setup with single bootstrap command
- **Cross-platform ready**: Template system supports macOS-specific installations
- **Minimal dependencies**: Reduced toolchain complexity by eliminating version managers

## Maintenance

### Clean Installation Reset

The `chezmoi-cleanup` fish function provides a comprehensive cleanup of all tool caches and data directories. This is useful when you want to reset your environment to a clean state:

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
