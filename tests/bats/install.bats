#!/usr/bin/env bats
# Post-install verification: checks that the bootstrap produced a working system.
# Replaces verify-installation.sh for Docker/CI use.
# Run: bats tests/bats/install.bats

load helpers/brew

setup_file() {
    setup_brew_env
}

# ── Core package manager ────────────────────────────────────────────────────

@test "brew is installed and in PATH" {
    command -v brew
}

@test "brew has packages installed" {
    local count
    count=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 10 ]
}

# ── Dotfiles manager ────────────────────────────────────────────────────────

@test "chezmoi is installed" {
    command -v chezmoi
}

# ── Core CLI tools (always installed in CI via Brewfile) ────────────────────

@test "git is installed" {
    command -v git
}

@test "fish is installed" {
    command -v fish
}

@test "jq is installed" {
    command -v jq
}

@test "tmux is installed" {
    command -v tmux
}

@test "starship is installed" {
    command -v starship
}

@test "fzf is installed" {
    command -v fzf
}

@test "ripgrep is installed" {
    command -v rg
}

# ── Dotfiles applied ────────────────────────────────────────────────────────

@test "bashrc exists" {
    [ -f "$HOME/.bashrc" ]
}

@test "zshrc exists" {
    [ -f "$HOME/.zshrc" ]
}

@test "config directory exists" {
    [ -d "$HOME/.config" ]
}

@test "fish config directory exists" {
    [ -d "$HOME/.config/fish" ]
}

@test "starship config exists" {
    [ -f "$HOME/.config/starship.toml" ]
}

@test "editorconfig exists" {
    [ -f "$HOME/.editorconfig" ]
}

# ── Shell sanity ────────────────────────────────────────────────────────────

@test "fish runs without errors" {
    fish -c "echo ok" | grep -q "^ok$"
}

@test "bash sources bashrc without errors" {
    run bash --norc -c "source ~/.bashrc 2>&1; echo ok"
    [[ "$output" == *"ok"* ]]
}
