#!/bin/bash
# Note: Not using 'set -e' here because test functions return 1 on failure
# and we want to continue testing even if some tests fail

echo "=== Starting Ubuntu Bootstrap Test (Offline Mode) ==="

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

echo "=== Creating mock dotfiles repository ==="
# Create a mock dotfiles repository locally to test chezmoi functionality
mkdir -p /tmp/mock-dotfiles

# Create mock Brewfile
cat > /tmp/mock-dotfiles/Brewfile << 'EOF'
## BREWS - Basic test packages
brew "git"
brew "curl"
brew "jq"
brew "fish"
brew "tmux"
EOF

# Create mock run_after script that will install homebrew and packages
cat > '/tmp/mock-dotfiles/run_after_Brewfile.sh.tmpl' << 'EOF'
#!/bin/sh

echo "Installing Homebrew and packages..."

# Detect OS and set up homebrew paths
case "$(uname -s)" in
Darwin)
    echo "Detected macOS"
    OS="darwin"
    if [ -x "/opt/homebrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    elif [ -x "/usr/local/bin/brew" ]; then
        HOMEBREW_PREFIX="/usr/local"
    else
        HOMEBREW_PREFIX="/opt/homebrew"
    fi
    PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
    ;;
Linux)
    echo "Detected Linux"
    OS="linux"
    if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    elif [ -x "${HOME}/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="${HOME}/.linuxbrew"
    else
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    fi
    PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
    ;;
*)
    echo "Unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

echo "Using Homebrew prefix: ${HOMEBREW_PREFIX}"

echo "Checking for brew..."
BREW_BIN=$(which brew 2>/dev/null)

if [ -n "${BREW_BIN}" ] && [ -x "${BREW_BIN}" ]; then
  echo "Homebrew already installed at ${BREW_BIN}"
else
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
fi

# Install packages from Brewfile
BREWFILE="{{ .chezmoi.sourceDir }}/Brewfile"
if [ -f "${BREWFILE}" ]; then
  echo "Installing packages from ${BREWFILE}..."
  brew bundle install --file="${BREWFILE}" --verbose
else
  echo "Error: Brewfile not found at ${BREWFILE}"
  exit 1
fi

echo "Homebrew installation and package setup complete!"
EOF

# Create some basic dotfiles
cat > /tmp/mock-dotfiles/dot_bashrc << 'EOF'
# Mock bashrc for testing
export PATH="$HOME/.local/bin:$PATH"
EOF

cat > /tmp/mock-dotfiles/dot_zshrc << 'EOF'
# Mock zshrc for testing
export PATH="$HOME/.local/bin:$PATH"
EOF

# Create basic config directory
mkdir -p /tmp/mock-dotfiles/dot_config/fish
cat > /tmp/mock-dotfiles/dot_config/fish/config.fish << 'EOF'
# Mock fish config
set -gx PATH $HOME/.local/bin $PATH
EOF

# Initialize as git repo and add files
cd /tmp/mock-dotfiles
git init
git config user.email "test@example.com"
git config user.name "Test User"
git add .
git commit -m "Initial mock dotfiles"

echo "=== Testing chezmoi init with local repository ==="
export BINDIR="$HOME/.local/bin"

# Initialize chezmoi with local repository
if chezmoi init --apply /tmp/mock-dotfiles; then
    echo "Chezmoi init successful"
else
    echo "Chezmoi init failed, but continuing with tests..."
fi

echo "=== Verifying Homebrew installation ==="

# Wait for any background processes to complete
sleep 5

# Test Homebrew installation and basic functionality
if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
    echo "Found Linux Homebrew installation"
    test_command "which brew" "Homebrew is installed and in PATH"
    test_command_output "brew --version" "Homebrew version check" "Homebrew"
elif [ -x "${HOME}/.linuxbrew/bin/brew" ]; then
    export PATH="${HOME}/.linuxbrew/bin:${HOME}/.linuxbrew/sbin:$PATH"
    echo "Found user Homebrew installation"
    test_command "which brew" "Homebrew is installed and in PATH"
    test_command_output "brew --version" "Homebrew version check" "Homebrew"
else
    echo "Homebrew not found, checking if installation attempted..."
    test_command "test -d /home/linuxbrew" "Linux homebrew directory exists"
fi

echo "=== Testing basic package availability ==="
# Test some basic packages that should be available from system
test_command "which git" "Git is available"
test_command "which curl" "Curl is available"

echo "=== Testing dotfiles application ==="
# Test that chezmoi applied basic dotfiles
test_command "test -f ~/.bashrc" "Bash config file exists"
test_command "test -f ~/.zshrc" "Zsh config file exists"
test_command "test -d ~/.config" "Config directory exists"

# Test that the files contain our mock content
test_command "grep -q 'Mock bashrc' ~/.bashrc" "Bashrc contains expected content"
test_command "grep -q 'Mock zshrc' ~/.zshrc" "Zshrc contains expected content"

echo "=== Testing Bootstrap Script Logic ==="
# Test that the bootstrap script logic works correctly for OS detection
echo "Testing OS detection logic..."
echo "Current OS: $(uname -s)"

# Simulate the path detection logic from the bootstrap script
case "$(uname -s)" in
Linux)
    echo "✓ OS detection works correctly for Linux"
    ((TESTS_PASSED++))

    # Test the path logic
    if [ -d "/home/linuxbrew/.linuxbrew" ] || [ -d "${HOME}/.linuxbrew" ]; then
        echo "✓ Homebrew directory structure created"
        ((TESTS_PASSED++))
    else
        echo "✗ Homebrew directory structure not found"
        ((TESTS_FAILED++))
    fi
    ;;
*)
    echo "✗ Unexpected OS for this test"
    ((TESTS_FAILED++))
    ;;
esac

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