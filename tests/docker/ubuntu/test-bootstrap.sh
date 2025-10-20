#!/bin/bash
# Note: Not using 'set -e' here because test functions return 1 on failure
# and we want to continue testing even if some tests fail

echo "=== Starting Ubuntu Bootstrap Test ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

test_command() {
    local cmd="$1"
    local description="$2"

    echo -e "${YELLOW}Testing: ${description}${NC}"
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS: ${description}${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL: ${description}${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_command_output() {
    local cmd="$1"
    local description="$2"
    local expected_pattern="$3"

    echo -e "${YELLOW}Testing: ${description}${NC}"
    local output=$(eval "$cmd" 2>&1)
    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}✓ PASS: ${description}${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL: ${description}${NC}"
        echo "Expected pattern: $expected_pattern"
        echo "Actual output: $output"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "=== Running chezmoi bootstrap ==="
# Run the bootstrap process using the local source (mounted in docker-compose)
# Check if we're in docker with the source mounted, otherwise use GitHub
if [ -d "/dotfiles-source" ]; then
    echo "Using local dotfiles source from /dotfiles-source"
    # Copy to a writable location and initialize as git repo since /dotfiles-source is mounted read-only
    echo "Copying source to writable location..."
    cp -r /dotfiles-source /tmp/dotfiles-source-copy

    # Make it a git repo if it isn't already (chezmoi needs a git repo)
    if [ ! -d "/tmp/dotfiles-source-copy/.git" ]; then
        echo "Initializing as git repository..."
        cd /tmp/dotfiles-source-copy
        git init
        git config user.email "test@example.com"
        git config user.name "Test User"
        git add .
        git commit -m "Initial commit" || true
        cd -
    fi

    # Use file:// URL to initialize from local git repo
    timeout 300 chezmoi init --apply file:///tmp/dotfiles-source-copy || {
        echo "Bootstrap failed"
        exit 1
    }
else
    echo "Using GitHub repository"
    timeout 300 chezmoi init https://github.com/jesserobertson/dotfiles.git --apply || {
        echo "Bootstrap failed"
        exit 1
    }
fi

echo "=== Verifying installation ==="

# Wait for any background processes to complete
sleep 5

# Test Homebrew installation
test_command "which brew" "Homebrew is installed and in PATH"
test_command_output "brew --version" "Homebrew version check" "Homebrew"

# Test core CLI tools from Brewfile (always installed)
test_command "which git" "Git is installed"
test_command "which fish" "Fish shell is installed"
test_command "which jq" "Jq is installed"
test_command "which tmux" "Tmux is installed"

# Test that chezmoi applied dotfiles
test_command "test -f ~/.bashrc" "Bash config file exists"
test_command "test -d ~/.config" "Config directory exists"

# In CI, we skip optional packages to save time
if [ -n "${CI:-}" ]; then
    echo "CI mode - skipping optional package checks (Rust, Haskell, cloud tools, etc.)"
else
    # Test additional CLI tools (not in CI)
    test_command "which nvim" "Neovim is installed"
    test_command "which bat" "Bat is installed"
    test_command "which fzf" "Fzf is installed"
    test_command "which gh" "GitHub CLI is installed"

    # Test programming languages
    test_command "which go" "Go is installed"
    test_command "which node" "Node.js is installed"
    test_command "which rustup" "Rustup is installed"

    # Test development tools
    test_command "which aws" "AWS CLI is installed"
    test_command "which tofu" "OpenTofu is installed"
    test_command "which packer" "Packer is installed"

    test_command "test -f ~/.zshrc" "Zsh config file exists"
fi

# Test Homebrew bundle was successful
test_command "brew list --formula | wc -l | grep -E '^[1-9][0-9]*$'" "Brew packages installed"

echo "=== Test Summary ==="
echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}=== ALL TESTS PASSED ===${NC}"
    exit 0
else
    echo -e "${RED}=== SOME TESTS FAILED ===${NC}"
    exit 1
fi