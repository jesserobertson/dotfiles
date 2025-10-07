#!/bin/bash
# Shell environment consistency test integrated with the overall test strategy
# This test verifies environment variable consistency across bash, zsh, and fish shells

set -e

# Colors for output (matching the test framework style)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking (matching verify-installation.sh pattern)
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Environment variables to check
ENV_VARS=(
    "EDITOR"
    "PAGER"
    "GIT_PAGER"
    "SSH_AUTH_SOCK"
    "CONFIG"
    "LOCAL"
    "LOCAL_BIN"
    "CARGO_HOME"
    "HOMEBREW_PREFIX"
    "HOMEBREW_CELLAR"
    "HOMEBREW_REPOSITORY"
    "MANPATH"
    "INFOPATH"
    "PATH"
)

# Function to test environment variable consistency
test_env_var_consistency() {
    local var="$1"
    local description="Test $var consistency across shells"

    echo -e "${YELLOW}Testing: ${description}${NC}"

    # Get values from each shell
    local bash_val zsh_val fish_val

    # Bash
    if command -v bash >/dev/null 2>&1 && [ -f "$HOME/.bashrc" ]; then
        bash_val=$(bash -c "source ~/.bashrc 2>/dev/null; echo \"\$$var\"" 2>/dev/null || echo "")
    else
        echo -e "${BLUE}⚬ SKIP: Bash not available or ~/.bashrc not found${NC}"
        ((TESTS_SKIPPED++))
        return 0
    fi

    # Zsh
    if command -v zsh >/dev/null 2>&1 && [ -f "$HOME/.zshrc" ]; then
        zsh_val=$(zsh -c "source ~/.zshrc 2>/dev/null; echo \"\$$var\"" 2>/dev/null || echo "")
    else
        echo -e "${BLUE}⚬ SKIP: Zsh not available or ~/.zshrc not found${NC}"
        ((TESTS_SKIPPED++))
        return 0
    fi

    # Fish
    if command -v fish >/dev/null 2>&1 && [ -f "$HOME/.config/fish/config.fish" ]; then
        if [[ "$var" == "PATH" || "$var" == "MANPATH" || "$var" == "INFOPATH" ]]; then
            # Fish uses space-separated paths, convert to colon-separated
            fish_val=$(fish -c "source ~/.config/fish/config.fish 2>/dev/null; string join ':' \$$var" 2>/dev/null || echo "")
        else
            fish_val=$(fish -c "source ~/.config/fish/config.fish 2>/dev/null; echo \$$var" 2>/dev/null || echo "")
        fi
    else
        echo -e "${BLUE}⚬ SKIP: Fish not available or config not found${NC}"
        ((TESTS_SKIPPED++))
        return 0
    fi

    # Normalize path-like variables for comparison
    if [[ "$var" == "PATH" ]]; then
        bash_val=$(normalize_path "$bash_val")
        zsh_val=$(normalize_path "$zsh_val")
        fish_val=$(normalize_path "$fish_val")

        # Special handling for homebrew paths - ensure they're present
        if ! check_homebrew_paths "$bash_val" "$zsh_val" "$fish_val"; then
            echo -e "${RED}✗ FAIL: ${description} - Homebrew paths missing or inconsistent${NC}"
            ((TESTS_FAILED++))
            return 1
        fi
    elif [[ "$var" == "MANPATH" || "$var" == "INFOPATH" ]]; then
        bash_val=$(normalize_man_info_path "$bash_val")
        zsh_val=$(normalize_man_info_path "$zsh_val")
        fish_val=$(normalize_man_info_path "$fish_val")
    fi

    # Compare values (allow for minor differences in path order)
    if [[ "$var" == "PATH" ]]; then
        if paths_equivalent "$bash_val" "$zsh_val" "$fish_val"; then
            echo -e "${GREEN}✓ PASS: ${description}${NC}"
            ((TESTS_PASSED++))
            return 0
        fi
    elif [[ "$var" == "MANPATH" || "$var" == "INFOPATH" ]]; then
        # For MANPATH and INFOPATH, just check that they're identical after normalization
        local path1_sorted=$(echo "$bash_val" | tr ':' '\n' | sort | tr '\n' ':')
        local path2_sorted=$(echo "$zsh_val" | tr ':' '\n' | sort | tr '\n' ':')
        local path3_sorted=$(echo "$fish_val" | tr ':' '\n' | sort | tr '\n' ':')

        if [[ "$path1_sorted" == "$path2_sorted" && "$path2_sorted" == "$path3_sorted" ]]; then
            echo -e "${GREEN}✓ PASS: ${description}${NC}"
            ((TESTS_PASSED++))
            return 0
        fi
    else
        if [[ "$bash_val" == "$zsh_val" && "$zsh_val" == "$fish_val" ]]; then
            echo -e "${GREEN}✓ PASS: ${description}${NC}"
            ((TESTS_PASSED++))
            return 0
        fi
    fi

    echo -e "${RED}✗ FAIL: ${description}${NC}"
    echo "  bash: $bash_val"
    echo "  zsh:  $zsh_val"
    echo "  fish: $fish_val"
    ((TESTS_FAILED++))
    return 1
}

# Function to normalize PATH for comparison (remove duplicates, sort)
normalize_path() {
    echo "$1" | tr ':' '\n' | grep -v '^$' | sort -u | tr '\n' ':'
}

# Function to normalize MANPATH/INFOPATH (handle empty values)
normalize_man_info_path() {
    local path="$1"
    # Remove trailing colons and empty entries
    echo "$path" | sed 's/:*$//' | tr ':' '\n' | grep -v '^$' | sort -u | tr '\n' ':'
}

# Function to check if paths are equivalent (allowing for order differences and conditional paths)
paths_equivalent() {
    local path1_norm="$1"
    local path2_norm="$2"
    local path3_norm="$3"

    # Check that all required homebrew paths are present in all shells
    if ! check_homebrew_paths "$path1_norm" "$path2_norm" "$path3_norm"; then
        return 1
    fi

    # For a more lenient comparison, check that the core paths are present
    # Allow for differences in conditional paths that may not exist on all systems
    local core_paths=(
        "$HOME/.local/bin"
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
        "/usr/bin"
        "/bin"
    )

    for core_path in "${core_paths[@]}"; do
        if [[ ":$path1_norm:" != *":$core_path:"* ]] || \
           [[ ":$path2_norm:" != *":$core_path:"* ]] || \
           [[ ":$path3_norm:" != *":$core_path:"* ]]; then
            echo "  Missing core path: $core_path"
            return 1
        fi
    done

    return 0
}

# Function to check for required homebrew paths
check_homebrew_paths() {
    local bash_path="$1"
    local zsh_path="$2"
    local fish_path="$3"

    # Define required homebrew paths based on platform
    local required_paths=()

    case "$(uname -s)" in
        Darwin)
            # macOS - check for /opt/homebrew (Apple Silicon) or /usr/local (Intel)
            if [ -d "/opt/homebrew" ]; then
                required_paths=("/opt/homebrew/bin" "/opt/homebrew/sbin")
            elif [ -d "/usr/local/homebrew" ] || [ -d "/usr/local/bin/brew" ]; then
                required_paths=("/usr/local/bin" "/usr/local/sbin")
            fi
            ;;
        Linux)
            # Linux - check for linuxbrew paths
            if [ -d "/home/linuxbrew/.linuxbrew" ]; then
                required_paths=("/home/linuxbrew/.linuxbrew/bin" "/home/linuxbrew/.linuxbrew/sbin")
            elif [ -d "$HOME/.linuxbrew" ]; then
                required_paths=("$HOME/.linuxbrew/bin" "$HOME/.linuxbrew/sbin")
            fi
            ;;
    esac

    # If no homebrew installation expected, skip this check
    if [ ${#required_paths[@]} -eq 0 ]; then
        return 0
    fi

    # Check that all required paths are present in all shell PATHs
    for req_path in "${required_paths[@]}"; do
        if [[ ":$bash_path:" != *":$req_path:"* ]] || \
           [[ ":$zsh_path:" != *":$req_path:"* ]] || \
           [[ ":$fish_path:" != *":$req_path:"* ]]; then
            echo "  Missing required homebrew path: $req_path"
            return 1
        fi
    done

    return 0
}

# Main execution
echo -e "${BLUE}=== Shell Environment Consistency Tests ===${NC}"
echo "OS: $(uname -s)"
echo "Architecture: $(uname -m)"
echo "Date: $(date)"
echo ""

# Test each environment variable
for var in "${ENV_VARS[@]}"; do
    test_env_var_consistency "$var"
    echo
done

# Summary (matching verify-installation.sh format)
echo "=== Test Summary ==="
echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
echo -e "Tests skipped: ${BLUE}${TESTS_SKIPPED}${NC}"
echo -e "Total tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}=== SHELL ENVIRONMENT TESTS PASSED ===${NC}"
    echo "Environment variables are consistent across all shells!"
    exit 0
else
    echo -e "${RED}=== SHELL ENVIRONMENT TESTS FAILED ===${NC}"
    echo "Some environment variables differ across shells."
    echo ""
    echo -e "${YELLOW}Please check your shell configuration files:${NC}"
    echo "  - ~/.bashrc"
    echo "  - ~/.zshrc"
    echo "  - ~/.config/fish/config.fish"
    echo "  - ~/.config/fish/env.fish"
    exit 1
fi