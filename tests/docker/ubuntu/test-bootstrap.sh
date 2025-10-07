#!/bin/bash
set -e

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
# Run the bootstrap process
export BINDIR="$HOME/.local/bin"
timeout 300 sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply jesserobertson || {
    echo "Bootstrap failed or timed out, trying HTTPS instead..."
    # Fallback to HTTPS if SSH fails
    timeout 300 chezmoi init https://github.com/jesserobertson/dotfiles.git --apply || {
        echo "Bootstrap failed with both SSH and HTTPS"
        exit 1
    }
}

echo "=== Verifying installation ==="

# Wait for any background processes to complete
sleep 5

# Test Homebrew installation
test_command "which brew" "Homebrew is installed and in PATH"
test_command_output "brew --version" "Homebrew version check" "Homebrew"

# Test core CLI tools from Brewfile
test_command "which git" "Git is installed"
test_command "which fish" "Fish shell is installed"
test_command "which nvim" "Neovim is installed"
test_command "which bat" "Bat is installed"
test_command "which eza" "Eza is installed"
test_command "which fd" "Fd is installed"
test_command "which fzf" "Fzf is installed"
test_command "which rg" "Ripgrep is installed"
test_command "which jq" "Jq is installed"
test_command "which tmux" "Tmux is installed"

# Test programming languages
test_command "which go" "Go is installed"
test_command "which node" "Node.js is installed"
test_command "which rustup" "Rustup is installed"

# Test development tools
test_command "which aws" "AWS CLI is installed"
test_command "which gcloud" "Google Cloud SDK is installed"
test_command "which terraform" "Terraform is installed"
test_command "which packer" "Packer is installed"

# Test that chezmoi applied dotfiles
test_command "test -f ~/.zshrc" "Zsh config file exists"
test_command "test -f ~/.bashrc" "Bash config file exists"
test_command "test -d ~/.config" "Config directory exists"

# Test Homebrew bundle was successful
test_command "brew list --formula | wc -l | grep -E '^[1-9][0-9]+$'" "Multiple brew packages installed"

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