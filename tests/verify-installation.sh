#!/bin/bash
# Comprehensive verification script for dotfiles installation
# Can be run on any system to verify the installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

test_command() {
    local cmd="$1"
    local description="$2"
    local is_optional="${3:-false}"

    echo -e "${YELLOW}Testing: ${description}${NC}"
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS: ${description}${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        if [ "$is_optional" = "true" ]; then
            echo -e "${BLUE}⚬ SKIP: ${description} (optional)${NC}"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            return 0
        else
            echo -e "${RED}✗ FAIL: ${description}${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

test_file_exists() {
    local file_path="$1"
    local description="$2"
    local is_optional="${3:-false}"

    echo -e "${YELLOW}Testing: ${description}${NC}"
    if [ -e "$file_path" ]; then
        echo -e "${GREEN}✓ PASS: ${description}${NC}"
        echo "  → Found at: $file_path"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        if [ "$is_optional" = "true" ]; then
            echo -e "${BLUE}⚬ SKIP: ${description} (optional)${NC}"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            return 0
        else
            echo -e "${RED}✗ FAIL: ${description}${NC}"
            echo "  → Expected at: $file_path"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

test_package_count() {
    local min_packages="$1"
    local package_type="$2"

    echo -e "${YELLOW}Testing: Sufficient ${package_type} packages installed${NC}"

    case "$package_type" in
        "brew")
            local count=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
            ;;
        "cask")
            local count=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')
            ;;
        *)
            echo -e "${RED}✗ FAIL: Unknown package type: ${package_type}${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
            ;;
    esac

    if [ "$count" -ge "$min_packages" ]; then
        echo -e "${GREEN}✓ PASS: ${count} ${package_type} packages installed (minimum: ${min_packages})${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL: Only ${count} ${package_type} packages installed (minimum: ${min_packages})${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "=== Dotfiles Installation Verification ==="
echo "OS: $(uname -s)"
echo "Architecture: $(uname -m)"
echo "Date: $(date)"
echo ""

# Core system checks
echo -e "${BLUE}=== Core System Checks ===${NC}"
test_command "which brew" "Homebrew is installed and in PATH"
test_command "which chezmoi" "Chezmoi is installed and in PATH"
test_command "which git" "Git is installed"

# Homebrew package verification
echo -e "${BLUE}=== Homebrew Package Verification ===${NC}"
if command -v brew >/dev/null 2>&1; then
    # Find and process Brewfile (now a template at packages/brewfile.tmpl)
    BREWFILE_PATH=""
    BREWFILE_TEMPLATE=""
    CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"

    if [ -f "$CHEZMOI_SOURCE/packages/brewfile.tmpl" ]; then
        BREWFILE_TEMPLATE="$CHEZMOI_SOURCE/packages/brewfile.tmpl"
    fi

    if [ -n "$BREWFILE_TEMPLATE" ] && command -v chezmoi >/dev/null 2>&1; then
        # Process the template to get the actual Brewfile content
        BREWFILE_PATH=$(mktemp /tmp/brewfile.XXXXXX)
        chezmoi execute-template < "$BREWFILE_TEMPLATE" > "$BREWFILE_PATH" 2>/dev/null || {
            rm -f "$BREWFILE_PATH"
            BREWFILE_PATH=""
        }
    elif [ -f "$HOME/.local/share/chezmoi/Brewfile" ]; then
        BREWFILE_PATH="$HOME/.local/share/chezmoi/Brewfile"
    elif [ -f "$HOME/Brewfile" ]; then
        BREWFILE_PATH="$HOME/Brewfile"
    elif [ -f "Brewfile" ]; then
        BREWFILE_PATH="Brewfile"
    fi

    if [ -n "$BREWFILE_PATH" ]; then
        # Count expected brew packages from Brewfile
        EXPECTED_BREWS=$(grep '^brew ' "$BREWFILE_PATH" | wc -l | tr -d ' ')
        test_package_count "$EXPECTED_BREWS" "brew"

        # Check for specific packages from Brewfile
        echo -e "${YELLOW}Checking packages from Brewfile: $BREWFILE_PATH${NC}"

        # Extract brew packages and test them
        while IFS= read -r line; do
            if [[ $line =~ ^brew[[:space:]]+\"([^\"]+)\" ]]; then
                package="${BASH_REMATCH[1]}"
                case "$package" in
                    "awscli")
                        test_command "which aws" "AWS CLI"
                        ;;
                    "bat")
                        test_command "which bat" "Bat (syntax highlighting)"
                        ;;
                    "eza")
                        test_command "which eza" "Eza (ls replacement)"
                        ;;
                    "fd")
                        test_command "which fd" "Fd (find replacement)"
                        ;;
                    "fish")
                        test_command "which fish" "Fish shell"
                        ;;
                    "fzf")
                        test_command "which fzf" "Fzf (fuzzy finder)"
                        ;;
                    "golang")
                        test_command "which go" "Go programming language"
                        ;;
                    "jq")
                        test_command "which jq" "jq (JSON processor)"
                        ;;
                    "neovim")
                        test_command "which nvim" "Neovim"
                        ;;
                    "nodejs")
                        test_command "which node" "Node.js"
                        ;;
                    "packer")
                        test_command "which packer" "Packer"
                        ;;
                    "ripgrep")
                        test_command "which rg" "Ripgrep"
                        ;;
                    "rustup")
                        test_command "which rustup" "Rust (via rustup)"
                        ;;
                    "starship")
                        test_command "which starship" "Starship prompt"
                        ;;
                    "terraform")
                        test_command "which terraform" "Terraform"
                        ;;
                    "tmux")
                        test_command "which tmux" "Tmux"
                        ;;
                    *)
                        # For other packages, try to test with the package name directly
                        test_command "which $package" "$package" true
                        ;;
                esac
            fi
        done < "$BREWFILE_PATH"
    else
        echo -e "${YELLOW}No Brewfile found, using fallback package checks${NC}"
        test_package_count 10 "brew"  # Fallback minimum

        # Basic fallback checks for common tools
        test_command "which fish" "Fish shell" true
        test_command "which nvim" "Neovim" true
        test_command "which git" "Git" true
    fi

    # Optional cask packages (only check on macOS)
    if [ "$(uname -s)" = "Darwin" ] && [ -n "$BREWFILE_PATH" ]; then
        echo -e "${BLUE}=== macOS Applications (Casks) ===${NC}"

        # Extract cask packages from Brewfile and test them
        while IFS= read -r line; do
            if [[ $line =~ ^cask[[:space:]]+\"([^\"]+)\" ]]; then
                cask="${BASH_REMATCH[1]}"
                case "$cask" in
                    "alacritty")
                        test_command "ls /Applications/Alacritty.app" "Alacritty terminal" true
                        ;;
                    "claude-code")
                        test_command "ls /Applications/Claude.app" "Claude Code" true
                        ;;
                    "raycast")
                        test_command "ls /Applications/Raycast.app" "Raycast" true
                        ;;
                    "1password-cli")
                        test_command "which op" "1Password CLI" true
                        ;;
                    "vagrant")
                        test_command "which vagrant" "Vagrant" true
                        ;;
                    font-*)
                        # Skip font checks as they're hard to verify reliably
                        echo -e "${BLUE}⚬ SKIP: Font package ${cask} (fonts are hard to verify)${NC}"
                        ((TESTS_SKIPPED++))
                        ;;
                    *)
                        # For other casks, try a generic application check
                        app_name=$(echo "$cask" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1' | sed 's/ //g')
                        test_command "ls /Applications/${app_name}.app" "$cask application" true
                        ;;
                esac
            fi
        done < "$BREWFILE_PATH"
    elif [ "$(uname -s)" = "Darwin" ]; then
        echo -e "${BLUE}=== macOS Applications (Casks) ===${NC}"
        echo -e "${YELLOW}No Brewfile found, using fallback cask checks${NC}"
        test_command "ls /Applications/Alacritty.app" "Alacritty terminal" true
        test_command "ls /Applications/Claude.app" "Claude Code" true
        test_command "ls /Applications/Raycast.app" "Raycast" true
    fi
else
    echo -e "${RED}Homebrew not found, skipping package verification${NC}"
fi

# Clean up temp Brewfile if we created one
if [[ "${BREWFILE_PATH:-}" == /tmp/brewfile.* ]]; then
    rm -f "$BREWFILE_PATH"
fi

# Dotfiles verification
echo -e "${BLUE}=== Dotfiles Configuration ===${NC}"
test_file_exists "$HOME/.zshrc" "Zsh configuration"
test_file_exists "$HOME/.bashrc" "Bash configuration"
test_file_exists "$HOME/.config" "Config directory"
test_file_exists "$HOME/.config/fish" "Fish shell configuration" true
test_file_exists "$HOME/.config/nvim" "Neovim configuration" true
test_file_exists "$HOME/.config/alacritty" "Alacritty configuration" true
test_file_exists "$HOME/.config/starship.toml" "Starship configuration" true
test_file_exists "$HOME/.editorconfig" "EditorConfig" true

# Shell integration tests
echo -e "${BLUE}=== Shell Integration Tests ===${NC}"
if command -v fish >/dev/null 2>&1; then
    test_command "fish -c 'echo test'" "Fish shell execution"
fi

if command -v starship >/dev/null 2>&1; then
    test_command "starship init fish" "Starship Fish integration"
    test_command "starship init zsh" "Starship Zsh integration"
fi

# Test chezmoi functionality
echo -e "${BLUE}=== Chezmoi Functionality ===${NC}"
test_command "chezmoi status" "Chezmoi status check" true
test_command "chezmoi verify" "Chezmoi verify" true

# Shell environment consistency tests
echo -e "${BLUE}=== Shell Environment Consistency ===${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SCRIPT_DIR/test-shell-env.sh" ]; then
    echo -e "${YELLOW}Running shell environment consistency tests...${NC}"
    if "$SCRIPT_DIR/test-shell-env.sh"; then
        echo -e "${GREEN}✓ PASS: Shell environment consistency tests${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL: Shell environment consistency tests${NC}"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${BLUE}⚬ SKIP: Shell environment test script not found (optional)${NC}"
    ((TESTS_SKIPPED++))
fi

echo ""
echo "=== Test Summary ==="
echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
echo -e "Tests skipped: ${BLUE}${TESTS_SKIPPED}${NC}"
echo -e "Total tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}=== VERIFICATION SUCCESSFUL ===${NC}"
    echo "Your dotfiles installation appears to be working correctly!"
    exit 0
else
    echo -e "${RED}=== VERIFICATION FAILED ===${NC}"
    echo "Some components are not working as expected. Please check the failed tests above."
    exit 1
fi