#!/usr/bin/env bats
# Repo hygiene checks: critical files exist, JSON configs are valid, no
# hardcoded home paths, no untracked conf.d files. No interpreter
# dependency beyond bash/git/find/jq.
# Run: bats tests/bats/repo-hygiene.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# ── Critical files ──────────────────────────────────────────────────────────

@test "dot_config/fish/config.fish exists" {
    [ -e "$REPO_ROOT/dot_config/fish/config.fish" ]
}

@test "dot_config/fish/alias.fish exists" {
    [ -e "$REPO_ROOT/dot_config/fish/alias.fish" ]
}

@test "dot_config/fish/conf.d/git-abbrs.fish exists" {
    [ -e "$REPO_ROOT/dot_config/fish/conf.d/git-abbrs.fish" ]
}

@test "dot_config/nvim/init.lua exists" {
    [ -e "$REPO_ROOT/dot_config/nvim/init.lua" ]
}

@test "dot_config/tmux/tmux.conf exists" {
    [ -e "$REPO_ROOT/dot_config/tmux/tmux.conf" ]
}

@test ".chezmoiignore.tmpl exists" {
    [ -e "$REPO_ROOT/.chezmoiignore.tmpl" ]
}

# ── JSON validity ────────────────────────────────────────────────────────────

@test "JSON configs are valid" {
    command -v jq >/dev/null 2>&1 || skip "jq not available"

    local failed=0
    local json_file
    while IFS= read -r -d '' json_file; do
        if ! jq empty "$json_file" 2>/dev/null; then
            echo "invalid JSON: ${json_file#$REPO_ROOT/}" >&2
            failed=1
        fi
    done < <(find "$REPO_ROOT" -name "*.json" -not -path "*/.*" -print0)

    [ "$failed" -eq 0 ]
}

# ── Common mistakes ──────────────────────────────────────────────────────────

@test "no hardcoded home directory paths" {
    ! grep -r "/Users/jess.robertson" "$REPO_ROOT/dot_config" 2>/dev/null \
        | grep -v "Binary file" \
        | grep -v "\.claude/" \
        | grep -q .
}

@test "no untracked files in fish conf.d" {
    [ -d "$REPO_ROOT/dot_config/fish/conf.d" ] || skip "conf.d directory not found"
    cd "$REPO_ROOT"
    ! git ls-files --others --exclude-standard dot_config/fish/conf.d/ | grep -q .
}
