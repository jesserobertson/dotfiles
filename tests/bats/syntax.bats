#!/usr/bin/env bats
# Syntax checks for fish, bash, PowerShell, and zsh files across the repo.
# Each test aggregates all failures in its file set into one message (bats
# can't dynamically generate @test blocks from a runtime file-discovery
# loop, so this keeps the "check every matching file, report all failures"
# behavior of the original quick-test.sh in a single test per language).
# Run: bats tests/bats/syntax.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "fish syntax" {
    command -v fish >/dev/null 2>&1 || skip "fish not available"

    local failed=0
    local file

    for file in "$REPO_ROOT/dot_config/fish"/*.fish; do
        [ -f "$file" ] || continue
        fish -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
    done

    if [ -d "$REPO_ROOT/dot_config/fish/conf.d" ]; then
        for file in "$REPO_ROOT/dot_config/fish/conf.d"/*.fish; do
            [ -f "$file" ] || continue
            fish -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
        done
    fi

    for func in source_if_exists edit; do
        file="$REPO_ROOT/dot_config/fish/functions/${func}.fish"
        [ -f "$file" ] || continue
        fish -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
    done

    [ "$failed" -eq 0 ]
}

@test "bash syntax" {
    command -v bash >/dev/null 2>&1 || skip "bash not available"

    local failed=0
    local file
    while IFS= read -r -d '' file; do
        bash -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
    done < <(find "$REPO_ROOT" -name "*.sh" -type f ! -path "*/.git/*" ! -path "*/node_modules/*" -print0)

    [ "$failed" -eq 0 ]
}

@test "powershell syntax" {
    command -v pwsh >/dev/null 2>&1 || skip "pwsh not available"

    local ps1_tmpl_render_dir=""
    local ps1_tmpl_render_dir_win=""
    if command -v chezmoi >/dev/null 2>&1; then
        ps1_tmpl_render_dir="$(mktemp -d)"
        # pwsh is a native Windows process, so pass it a Windows-style path
        # rather than a Git Bash /tmp/... POSIX path it can't resolve.
        if command -v cygpath >/dev/null 2>&1; then
            ps1_tmpl_render_dir_win="$(cygpath -w "$ps1_tmpl_render_dir")"
        else
            ps1_tmpl_render_dir_win="$ps1_tmpl_render_dir"
        fi
        local tmpl_file rendered_name
        while IFS= read -r -d '' tmpl_file; do
            rendered_name="$(basename "$tmpl_file" .tmpl)"
            env CI=true chezmoi execute-template < "$tmpl_file" > "$ps1_tmpl_render_dir/$rendered_name" 2>/dev/null
        done < <(find "$REPO_ROOT" -name "*.ps1.tmpl" -not -path "*/.git/*" -print0)
    fi

    local checker_dir checker_script
    checker_dir="$(mktemp -d)"
    checker_script="$checker_dir/checker.ps1"
    cat > "$checker_script" <<'PS1EOF'
param([string]$ExtraDir)
$failed = $false
$dirs = @('.')
if ($ExtraDir) { $dirs += $ExtraDir }
Get-ChildItem -Path $dirs -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -notmatch '\.git' } | ForEach-Object {
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        Write-Host "FAIL: $($_.Name): $($parseErrors -join '; ')"
        $failed = $true
    }
}
if ($failed) { exit 1 }
PS1EOF

    cd "$REPO_ROOT"
    run pwsh -NoProfile -NonInteractive -File "$checker_script" -ExtraDir "$ps1_tmpl_render_dir_win"

    rm -rf "$checker_dir"
    [ -n "$ps1_tmpl_render_dir" ] && rm -rf "$ps1_tmpl_render_dir"

    [ "$status" -eq 0 ]
}

@test "zsh syntax" {
    command -v zsh >/dev/null 2>&1 || skip "zsh not available"

    local failed=0

    if [ -f "$REPO_ROOT/dot_zshrc.tmpl" ] && command -v chezmoi >/dev/null 2>&1; then
        if ! env CI=true chezmoi execute-template < "$REPO_ROOT/dot_zshrc.tmpl" 2>/dev/null | zsh -n 2>/dev/null; then
            echo "syntax error: dot_zshrc.tmpl (after template processing)" >&2
            failed=1
        fi
    fi

    local file
    while IFS= read -r -d '' file; do
        zsh -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
    done < <(find "$REPO_ROOT" -name "*.zsh" -type f ! -path "*/.git/*" -print0)

    [ "$failed" -eq 0 ]
}
