#!/usr/bin/env bats
# Verifies that key environment variables are set consistently across
# bash, zsh, and fish after the dotfiles are applied.
# Run: bats tests/bats/shell-env.bats

load helpers/brew

setup_file() {
    setup_brew_env
    # Find the actual Homebrew prefix at runtime (cross-platform)
    export DETECTED_BREW_PREFIX
    DETECTED_BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "")
}

# Helper: get a variable's value from bash (non-interactive, sources ~/.bashrc)
_bash_var() {
    bash --norc -c "source ~/.bashrc 2>/dev/null; printf '%s' \"\$$1\""
}

# Helper: get a variable's value from zsh (sources ~/.zshrc)
_zsh_var() {
    zsh --no-rcs -c "source ~/.zshrc 2>/dev/null; printf '%s' \"\$$1\""
}

# Helper: get a variable's value from fish
_fish_var() {
    fish -c "printf '%s' \"\$$1\"" 2>/dev/null
}

# Helper: check that a string is in bash PATH
_bash_path_contains() {
    local dir="$1"
    bash --norc -c "source ~/.bashrc 2>/dev/null; echo \$PATH" | tr ':' '\n' | grep -qxF "$dir"
}

# ── EDITOR ──────────────────────────────────────────────────────────────────

@test "bash sets EDITOR" {
    run _bash_var EDITOR
    [ -n "$output" ]
}

@test "zsh sets EDITOR" {
    command -v zsh || skip "zsh not available"
    run _zsh_var EDITOR
    [ -n "$output" ]
}

@test "fish sets EDITOR" {
    run _fish_var EDITOR
    [ -n "$output" ]
}

@test "EDITOR is consistent across bash and fish" {
    local bash_val fish_val
    bash_val=$(_bash_var EDITOR)
    fish_val=$(_fish_var EDITOR)
    [ "$bash_val" = "$fish_val" ]
}

# ── PAGER ───────────────────────────────────────────────────────────────────

@test "bash sets PAGER" {
    run _bash_var PAGER
    [ -n "$output" ]
}

@test "PAGER is consistent across bash and fish" {
    local bash_val fish_val
    bash_val=$(_bash_var PAGER)
    fish_val=$(_fish_var PAGER)
    [ "$bash_val" = "$fish_val" ]
}

# ── Homebrew in PATH ─────────────────────────────────────────────────────────

@test "bash PATH includes homebrew bin" {
    [ -n "$DETECTED_BREW_PREFIX" ] || skip "Homebrew not found"
    _bash_path_contains "$DETECTED_BREW_PREFIX/bin"
}

@test "fish PATH includes homebrew bin" {
    [ -n "$DETECTED_BREW_PREFIX" ] || skip "Homebrew not found"
    fish -c "contains $DETECTED_BREW_PREFIX/bin \$PATH; and echo yes" | grep -q "^yes$"
}

# ── XDG dirs ────────────────────────────────────────────────────────────────

@test "bash sets CONFIG" {
    local val
    val=$(_bash_var CONFIG)
    [ "$val" = "$HOME/.config" ]
}

@test "fish sets CONFIG" {
    local val
    val=$(_fish_var CONFIG)
    [ "$val" = "$HOME/.config" ]
}
