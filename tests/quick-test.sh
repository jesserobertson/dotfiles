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

# Test 2: Validate Chezmoi can process templates
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

# Test 3: Check critical files exist
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

# Test 4: Validate JSON configs
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

# Test 5: Check for common mistakes
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
