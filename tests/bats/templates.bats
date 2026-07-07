#!/usr/bin/env bats
# Chezmoi template processing checks: templates render without error, and
# the [[data.env_vars]] single source of truth (.chezmoi.toml.tmpl) actually
# reaches the bash and fish env templates.
# Run: bats tests/bats/templates.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# ── Chezmoi-dependent (skip if chezmoi isn't installed) ─────────────────────

@test "chezmoi ignore template renders" {
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not available"
    run env CI=true chezmoi execute-template < "$REPO_ROOT/.chezmoiignore.tmpl"
    [ "$status" -eq 0 ]
}

@test "chezmoi dry-run applies cleanly" {
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not available"
    cd "$REPO_ROOT"
    run env CI=true timeout 30 chezmoi apply --dry-run
    [ "$status" -eq 0 ]
}

@test "env_vars render into bash env.sh.tmpl" {
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not available"
    local rendered
    rendered="$(env CI=true chezmoi execute-template < "$REPO_ROOT/dot_config/bash/env.sh.tmpl")"
    echo "$rendered" | grep -q 'export EDITOR='
    echo "$rendered" | grep -q 'export CARGO_HOME='
    echo "$rendered" | grep -q 'export HOMEBREW_PREFIX='
}

@test "env_vars render into fish env.fish.tmpl" {
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not available"
    local rendered
    rendered="$(env CI=true chezmoi execute-template < "$REPO_ROOT/dot_config/fish/env.fish.tmpl")"
    echo "$rendered" | grep -q 'set -gx EDITOR '
    echo "$rendered" | grep -q 'set -gx CARGO_HOME '
    echo "$rendered" | grep -q 'set -gx HOMEBREW_PREFIX '
}

# ── Always run, no chezmoi dependency ───────────────────────────────────────

@test "env_vars declared in .chezmoi.toml.tmpl" {
    for var in EDITOR CARGO_HOME HOMEBREW_PREFIX; do
        grep -q "\"${var}\"" "$REPO_ROOT/.chezmoi.toml.tmpl"
    done
}

@test "bash and fish templates loop over env_vars" {
    grep -q 'range \.env_vars' "$REPO_ROOT/dot_config/bash/env.sh.tmpl"
    grep -q 'range \.env_vars' "$REPO_ROOT/dot_config/fish/env.fish.tmpl"
}

@test "dot_bashrc.tmpl and dot_zshrc.tmpl source the shared env file" {
    for rc in "$REPO_ROOT/dot_bashrc.tmpl" "$REPO_ROOT/dot_zshrc.tmpl"; do
        grep -q "^source " "$rc"
    done
}
