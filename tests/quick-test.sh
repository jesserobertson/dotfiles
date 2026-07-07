#!/usr/bin/env bash
# Quick validation tests for dotfiles
# These run in seconds and catch common errors

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

log() {
    echo -e "${BLUE}▶${NC} $*"
}

pass() {
    echo -e "${GREEN}✓${NC} $*"
}

fail() {
    echo -e "${RED}✗${NC} $*"
    FAILED=1
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

echo ""
echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Quick Dotfiles Validation Tests  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# Test 1: Validate Fish shell syntax
log "Testing Fish shell syntax..."
if command -v fish >/dev/null 2>&1; then
    fish_errors=0

    # Check main config files
    for file in "$REPO_ROOT/dot_config/fish"/*.fish; do
        if [ -f "$file" ]; then
            if fish -n "$file" 2>/dev/null; then
                pass "$(basename "$file") syntax OK"
            else
                fail "$(basename "$file") has syntax errors"
                fish_errors=1
            fi
        fi
    done

    # Check conf.d files
    if [ -d "$REPO_ROOT/dot_config/fish/conf.d" ]; then
        for file in "$REPO_ROOT/dot_config/fish/conf.d"/*.fish; do
            if [ -f "$file" ]; then
                if fish -n "$file" 2>/dev/null; then
                    pass "conf.d/$(basename "$file") syntax OK"
                else
                    fail "conf.d/$(basename "$file") has syntax errors"
                    fish_errors=1
                fi
            fi
        done
    fi

    # Check critical functions
    for func in source_if_exists edit; do
        file="$REPO_ROOT/dot_config/fish/functions/${func}.fish"
        if [ -f "$file" ]; then
            if fish -n "$file" 2>/dev/null; then
                pass "functions/${func}.fish syntax OK"
            else
                fail "functions/${func}.fish has syntax errors"
                fish_errors=1
            fi
        fi
    done

    [ $fish_errors -eq 0 ] || FAILED=1
else
    warn "Fish not installed, skipping syntax checks"
fi
echo ""

# Test 2: Validate Bash script syntax
log "Testing Bash script syntax..."
if command -v bash >/dev/null 2>&1; then
    bash_errors=0

    # Check all .sh files in the repo (excluding .git and node_modules)
    while IFS= read -r -d '' file; do
        # Skip files in .git, node_modules, and other common exclusions
        if [[ "$file" =~ \.git/ ]] || [[ "$file" =~ node_modules/ ]]; then
            continue
        fi

        if bash -n "$file" 2>/dev/null; then
            # Show relative path from repo root
            rel_path="${file#$REPO_ROOT/}"
            pass "${rel_path} syntax OK"
        else
            rel_path="${file#$REPO_ROOT/}"
            fail "${rel_path} has syntax errors"
            bash_errors=1
        fi
    done < <(find "$REPO_ROOT" -name "*.sh" -type f ! -path "*/.git/*" ! -path "*/node_modules/*" -print0)

    [ $bash_errors -eq 0 ] || FAILED=1
else
    warn "Bash not installed, skipping syntax checks"
fi
echo ""

# Test 2b: Validate PowerShell script syntax
log "Testing PowerShell script syntax..."
if command -v pwsh >/dev/null 2>&1; then
    # *.ps1.tmpl files (e.g. profile.ps1.tmpl) contain chezmoi template syntax
    # that isn't valid PowerShell on its own, so render them first and parse
    # the rendered output instead of the source.
    ps1_tmpl_render_dir=""
    ps1_tmpl_render_dir_win=""
    if command -v chezmoi >/dev/null 2>&1; then
        ps1_tmpl_render_dir="$(mktemp -d)"
        # pwsh is a native Windows process, so pass it a Windows-style path
        # rather than the Git Bash /tmp/... POSIX path (which it can't resolve).
        if command -v cygpath >/dev/null 2>&1; then
            ps1_tmpl_render_dir_win="$(cygpath -w "$ps1_tmpl_render_dir")"
        else
            ps1_tmpl_render_dir_win="$ps1_tmpl_render_dir"
        fi
        while IFS= read -r -d '' tmpl_file; do
            rendered_name="$(basename "$tmpl_file" .tmpl)"
            env CI=true chezmoi execute-template < "$tmpl_file" > "$ps1_tmpl_render_dir/$rendered_name" 2>/dev/null
        done < <(find "$REPO_ROOT" -name "*.ps1.tmpl" -not -path "*/.git/*" -print0)
    else
        warn "chezmoi not installed, skipping *.ps1.tmpl rendering (syntax unchecked)"
    fi

    # Run pwsh from REPO_ROOT so it resolves paths natively (avoids Git Bash /c/... path issues)
    if pushd "$REPO_ROOT" > /dev/null 2>&1 && pwsh -NoProfile -NonInteractive -Command "
        \$failed = \$false
        \$dirs = @('.')
        if ('$ps1_tmpl_render_dir_win') { \$dirs += '$ps1_tmpl_render_dir_win' }
        Get-ChildItem -Path \$dirs -Recurse -Filter '*.ps1' | Where-Object { \$_.FullName -notmatch '\\.git' } | ForEach-Object {
            \$parseErrors = \$null
            [void][System.Management.Automation.Language.Parser]::ParseFile(\$_.FullName, [ref]\$null, [ref]\$parseErrors)
            if (\$parseErrors.Count -gt 0) {
                Write-Host \"FAIL: \$(\$_.Name): \$(\$parseErrors -join '; ')\"
                \$failed = \$true
            } else {
                Write-Host \"OK:   \$(\$_.Name)\"
            }
        }
        if (\$failed) { exit 1 }
    " && popd > /dev/null 2>&1; then
        pass "All PowerShell files have valid syntax"
    else
        popd > /dev/null 2>&1 || true
        fail "Some PowerShell files have syntax errors (see above)"
        FAILED=1
    fi
    [ -n "$ps1_tmpl_render_dir" ] && rm -rf "$ps1_tmpl_render_dir"
else
    warn "pwsh not installed, skipping PowerShell syntax checks"
fi
echo ""

# Test 3: Validate Zsh configuration syntax
log "Testing Zsh configuration syntax..."
if command -v zsh >/dev/null 2>&1; then
    zsh_errors=0

    # Check zshrc template (need to process it first to check syntax)
    if [ -f "$REPO_ROOT/dot_zshrc.tmpl" ]; then
        if command -v chezmoi >/dev/null 2>&1; then
            # Process template and check syntax
            if env CI=true chezmoi execute-template < "$REPO_ROOT/dot_zshrc.tmpl" 2>/dev/null | zsh -n 2>/dev/null; then
                pass "dot_zshrc.tmpl syntax OK (after template processing)"
            else
                fail "dot_zshrc.tmpl has syntax errors"
                zsh_errors=1
            fi
        else
            warn "Chezmoi not available, skipping zshrc template syntax check"
        fi
    fi

    # Check any direct .zsh files
    while IFS= read -r -d '' file; do
        if zsh -n "$file" 2>/dev/null; then
            rel_path="${file#$REPO_ROOT/}"
            pass "${rel_path} syntax OK"
        else
            rel_path="${file#$REPO_ROOT/}"
            fail "${rel_path} has syntax errors"
            zsh_errors=1
        fi
    done < <(find "$REPO_ROOT" -name "*.zsh" -type f ! -path "*/.git/*" -print0)

    [ $zsh_errors -eq 0 ] || FAILED=1
else
    warn "Zsh not installed, skipping syntax checks"
fi
echo ""

# Test 4: Validate Chezmoi can process templates
log "Testing Chezmoi template processing..."
if command -v chezmoi >/dev/null 2>&1; then
    cd "$REPO_ROOT"

    # Test in CI mode to avoid 1Password requirements
    if env CI=true chezmoi execute-template < .chezmoiignore.tmpl >/dev/null 2>&1; then
        pass "Chezmoi ignore template processes correctly"
    else
        fail "Chezmoi ignore template has errors"
    fi

    # Dry run to check for template errors
    if env CI=true timeout 30 chezmoi apply --dry-run >/dev/null 2>&1; then
        pass "Chezmoi dry-run completes without errors"
    else
        fail "Chezmoi dry-run found errors"
    fi
else
    warn "Chezmoi not installed, skipping template checks"
fi
echo ""

# Test 5: Check critical files exist
log "Checking critical files..."
critical_files=(
    "dot_config/fish/config.fish"
    "dot_config/fish/alias.fish"
    "dot_config/fish/conf.d/git-abbrs.fish"
    "dot_config/nvim/init.lua"
    "dot_config/tmux/tmux.conf"
    ".chezmoiignore.tmpl"
)

for file in "${critical_files[@]}"; do
    if [ -e "$REPO_ROOT/$file" ]; then
        pass "$file exists"
    else
        fail "$file is missing"
    fi
done
echo ""

# Test 6: Validate JSON configs
log "Validating JSON configuration files..."
if command -v jq >/dev/null 2>&1; then
    while IFS= read -r -d '' json_file; do
        if jq empty "$json_file" 2>/dev/null; then
            pass "$(basename "$json_file") is valid JSON"
        else
            fail "$(basename "$json_file") has invalid JSON"
        fi
    done < <(find "$REPO_ROOT" -name "*.json" -not -path "*/.*" -print0)
else
    warn "jq not installed, skipping JSON validation"
fi
echo ""

# Test 7: Check shell environment consistency
log "Checking shell environment variable consistency..."
env_errors=0

# Critical environment variables that should be set in all shells
critical_vars=(
    "EDITOR"
    "CARGO_HOME"
    "HOMEBREW_PREFIX"
)

# Bash/fish/PowerShell each `range` over the [[data.env_vars]] /
# [[data.homebrew_env_vars]] lists in .chezmoi.toml.tmpl (single source of
# truth for *which* vars get exported), so the per-shell templates no longer
# contain literal `export NAME` / `set -gx NAME` text for any given var. Check
# the rendered output instead, and fall back to a static check if chezmoi
# isn't available.
toml_config="$REPO_ROOT/.chezmoi.toml.tmpl"
fish_config="$REPO_ROOT/dot_config/fish/env.fish.tmpl"
shared_env_config="$REPO_ROOT/dot_config/bash/env.sh.tmpl"

if command -v chezmoi >/dev/null 2>&1; then
    rendered_bash="$(env CI=true chezmoi execute-template < "$shared_env_config" 2>/dev/null)"
    rendered_fish="$(env CI=true chezmoi execute-template < "$fish_config" 2>/dev/null)"

    for var in "${critical_vars[@]}"; do
        if ! echo "$rendered_bash" | grep -q "export $var="; then
            fail "Bash/Zsh: $var not exported by rendered env.sh.tmpl"
            env_errors=1
        fi
        if ! echo "$rendered_fish" | grep -q "set -gx $var "; then
            fail "Fish: $var not exported by rendered env.fish.tmpl"
            env_errors=1
        fi
    done
    if [ $env_errors -eq 0 ]; then
        pass "Bash/Zsh and Fish: all critical variables rendered"
    fi
else
    warn "chezmoi not installed, falling back to static template checks"
    for var in "${critical_vars[@]}"; do
        if ! grep -q "\"${var}\"" "$toml_config" 2>/dev/null; then
            fail "$var not declared in .chezmoi.toml.tmpl env_vars/homebrew_env_vars"
            env_errors=1
        fi
    done
    for f in "$fish_config" "$shared_env_config"; do
        if ! grep -q "range \.env_vars" "$f" 2>/dev/null; then
            fail "$(basename "$f") no longer loops over .env_vars"
            env_errors=1
        fi
    done
    if [ $env_errors -eq 0 ]; then
        pass "Bash/Zsh and Fish: env_vars loop and declarations present"
    fi
fi

# dot_bashrc.tmpl and dot_zshrc.tmpl just source the shared env file
for rc in "$REPO_ROOT/dot_bashrc.tmpl" "$REPO_ROOT/dot_zshrc.tmpl"; do
    if ! grep -q "^source " "$rc" 2>/dev/null; then
        fail "$(basename "$rc") no longer sources the shared env file"
        env_errors=1
    fi
done

[ $env_errors -eq 0 ] || FAILED=1
echo ""

# Test 8: Check for common mistakes
log "Checking for common configuration mistakes..."
mistakes=0

# Check for hardcoded home paths (exclude .claude directories)
if grep -r "/Users/jess.robertson" "$REPO_ROOT/dot_config" 2>/dev/null | \
   grep -v "Binary file" | \
   grep -v "\.claude/" | \
   grep -q .; then
    fail "Found hardcoded home directory paths"
    mistakes=1
else
    pass "No hardcoded home directory paths"
fi

# Check for untracked conf.d files
if [ -d "$REPO_ROOT/dot_config/fish/conf.d" ]; then
    cd "$REPO_ROOT"
    if git ls-files --others --exclude-standard dot_config/fish/conf.d/ | grep -q .; then
        fail "Found untracked files in conf.d/"
        mistakes=1
    else
        pass "All conf.d files are tracked"
    fi
fi

[ $mistakes -eq 0 ] || FAILED=1
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════${NC}"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All quick tests passed!${NC}"
    echo ""
    echo "Run full tests with:"
    echo "  ./run-local-tests.sh      # Feature tests (fast)"
    echo "  ./run-tests.sh            # Full bootstrap tests (slow)"
else
    echo -e "${RED}✗ Some tests failed${NC}"
fi
echo -e "${BLUE}════════════════════════════════════${NC}"
echo ""

exit $FAILED
