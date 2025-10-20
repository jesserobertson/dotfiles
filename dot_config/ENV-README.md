# Environment Variable Setup

This dotfiles repo uses a **single source of truth** for environment variables across all shells.

## Architecture

### Data Source
All environment variables are defined in `.chezmoi.toml.tmpl` under the `[data]` section. This includes:
- XDG Base Directory paths
- Tool homes (Rust, Haskell, Homebrew)
- Editor/pager preferences
- CPU info
- OS-specific paths

### Shell-Specific Env Files

Each shell has its own env file that templates from the same data:

- **Bash**: `~/.config/bash/env.sh` - Full environment setup
- **Zsh**: `~/.config/zsh/env.zsh` - Sources bash env (they're compatible)
- **Fish**: `~/.config/fish/env.fish` - Fish-specific syntax, same data

## Benefits

1. **DRY**: Define environment once, use everywhere
2. **Consistency**: Same PATH and env vars across all shells
3. **Maintainability**: Update `.chezmoi.toml.tmpl` to change all shells
4. **OS-Aware**: Homebrew paths, SSH agent, etc. adapt to OS

## Usage

### In Scripts

When writing run scripts for chezmoi (bash or fish), source the appropriate env file:

```bash
# Bash script
source ~/.config/bash/env.sh
```

```fish
# Fish script
source ~/.config/fish/env.fish
```

This ensures scripts have access to the same environment as interactive shells.

## Adding New Environment Variables

1. Add the variable to `.chezmoi.toml.tmpl` under `[data]`
2. Add it to the shell-specific env files using the template syntax:
   - Bash/Zsh: `export VAR_NAME="{{ .var_name }}"`
   - Fish: `set -gx VAR_NAME "{{ .var_name }}"`
3. Run `chezmoi apply` to update all env files
