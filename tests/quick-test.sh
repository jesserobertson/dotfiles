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

# Check Fish config
fish_config="$REPO_ROOT/dot_config/fish/env.fish.tmpl"
if [ -f "$fish_config" ]; then
    for var in "${critical_vars[@]}"; do
        if grep -q "set -gx $var" "$fish_config" 2>/dev/null || \
           grep -q "fish_add_path.*$var" "$fish_config" 2>/dev/null; then
            : # Variable found, do nothing
        else
            fail "Fish: $var not set in env.fish.tmpl"
            env_errors=1
        fi
    done
    if [ $env_errors -eq 0 ]; then
        pass "Fish: All critical variables defined"
    fi
else
    warn "Fish env config not found"
fi

# Check Zsh config
zsh_config="$REPO_ROOT/dot_zshrc.tmpl"
if [ -f "$zsh_config" ]; then
    for var in "${critical_vars[@]}"; do
        if grep -q "export $var" "$zsh_config" 2>/dev/null || \
           grep -q "path=.*$var" "$zsh_config" 2>/dev/null; then
            : # Variable found, do nothing
        else
            fail "Zsh: $var not set in .zshrc.tmpl"
            env_errors=1
        fi
    done
    if [ $env_errors -eq 0 ]; then
        pass "Zsh: All critical variables defined"
    fi
else
    warn "Zsh config not found"
fi

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
    echo "  docker-compose up         # Full bootstrap tests (slow)"
else
    echo -e "${RED}✗ Some tests failed${NC}"
fi
echo -e "${BLUE}════════════════════════════════════${NC}"
echo ""

exit $FAILED
