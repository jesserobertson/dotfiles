#!/usr/bin/env bats
# Tests for fish shell configuration after dotfiles are applied.
# Run: bats tests/bats/fish.bats

load helpers/brew

setup_file() {
    setup_brew_env
    command -v fish || skip "fish not installed"
}

# ── Startup ──────────────────────────────────────────────────────────────────

@test "fish starts without errors" {
    run fish -c "echo ok"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "fish config.fish parses without errors" {
    [ -f "$HOME/.config/fish/config.fish" ] || skip "config.fish not found"
    run fish --no-execute "$HOME/.config/fish/config.fish"
    [ "$status" -eq 0 ]
}

@test "fish env.fish parses without errors" {
    [ -f "$HOME/.config/fish/env.fish" ] || skip "env.fish not found"
    run fish --no-execute "$HOME/.config/fish/env.fish"
    [ "$status" -eq 0 ]
}

# ── Config files ─────────────────────────────────────────────────────────────

@test "fish config directory exists" {
    [ -d "$HOME/.config/fish" ]
}

@test "fish conf.d directory exists" {
    [ -d "$HOME/.config/fish/conf.d" ]
}

@test "fish functions directory exists" {
    [ -d "$HOME/.config/fish/functions" ]
}

# ── Environment variables ─────────────────────────────────────────────────────

@test "fish sets EDITOR" {
    run fish -c "printf '%s' \$EDITOR"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "fish sets PAGER" {
    run fish -c "printf '%s' \$PAGER"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "fish sets CONFIG to ~/.config" {
    run fish -c "printf '%s' \$CONFIG"
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.config" ]
}

# ── Init caching functions ────────────────────────────────────────────────────

@test "init_cached function is defined in fish" {
    run fish -c "type init_cached; and echo defined"
    [[ "$output" == *"defined"* ]]
}

# ── Tool integrations ─────────────────────────────────────────────────────────

@test "starship init runs without errors in fish" {
    command -v starship || skip "starship not installed"
    run fish -c "starship init fish | head -1"
    [ "$status" -eq 0 ]
}

@test "zoxide init runs without errors in fish" {
    command -v zoxide || skip "zoxide not installed"
    run fish -c "zoxide init fish | head -1"
    [ "$status" -eq 0 ]
}

@test "fzf --fish runs without errors" {
    command -v fzf || skip "fzf not installed"
    run fish -c "fzf --fish | head -1"
    [ "$status" -eq 0 ]
}
