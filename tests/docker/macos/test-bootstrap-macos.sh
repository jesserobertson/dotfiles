#!/bin/bash
# Note: Not using 'set -e' here because test functions return 1 on failure
# and we want to continue testing even if some tests fail

echo "=== Starting macOS-like Bootstrap Test ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo -e "${BLUE}=== Simulating macOS environment for path testing ===${NC}"
# Note: This is running on Linux but testing macOS-compatible paths

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

# Test Homebrew installation (will be Linux Homebrew in this container)
test_command "which brew" "Homebrew is installed and in PATH"
test_command_output "brew --version" "Homebrew version check" "Homebrew"

# Test that the bootstrap script would detect the correct OS
echo -e "${BLUE}=== Testing OS detection logic ===${NC}"
echo "Current OS detection would see: $(uname -s)"

# Test core CLI tools from Brewfile
echo -e "${BLUE}=== Testing core CLI tools ===${NC}"
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
echo -e "${BLUE}=== Testing programming languages ===${NC}"
test_command "which go" "Go is installed"
test_command "which node" "Node.js is installed"
test_command "which rustup" "Rustup is installed"

# Test development tools
echo -e "${BLUE}=== Testing development tools ===${NC}"
test_command "which aws" "AWS CLI is installed"
test_command "which gcloud" "Google Cloud SDK is installed"
test_command "which terraform" "Terraform is installed"
test_command "which packer" "Packer is installed"

# Test that chezmoi applied dotfiles
echo -e "${BLUE}=== Testing dotfiles application ===${NC}"
test_command "test -f ~/.zshrc" "Zsh config file exists"
test_command "test -f ~/.bashrc" "Bash config file exists"
test_command "test -d ~/.config" "Config directory exists"

# Test Homebrew bundle was successful
echo -e "${BLUE}=== Testing Homebrew package installation ===${NC}"
test_command "brew list --formula | wc -l | grep -E '^[1-9][0-9]+$'" "Multiple brew packages installed"

# Test specific macOS-oriented packages (casks won't install on Linux but formulas should)
echo -e "${BLUE}=== Testing macOS-specific considerations ===${NC}"
echo "Note: GUI applications (casks) cannot be tested in this Linux environment"
echo "but the Brewfile parsing and formula installation is validated"

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