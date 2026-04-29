#!/bin/bash
set -eu

## INSTALL HOMEBREW
echo "Installing Homebrew..."

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
BREW_BIN=$(which brew 2>/dev/null || true)

if [ -n "${BREW_BIN}" ] && [ -x "${BREW_BIN}" ]; then
  echo "Homebrew already installed at ${BREW_BIN}"
else
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
fi

## INSTALL 1PASSWORD (needed for templates, optional in CI)
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ]; then
  echo "CI environment detected, skipping 1Password CLI installation"
elif [ "${OS}" = "linux" ]; then
  echo "Linux detected - 1Password CLI installation skipped (cask not available)"
  echo "To install manually, see: https://developer.1password.com/docs/cli/get-started/"
else
  OP_BIN=$(which op 2>/dev/null || true)
  if [ -n "${OP_BIN}" ] && [ -x "${OP_BIN}" ]; then
    echo "1Password (op) already installed at ${OP_BIN}"
  else
    echo "1Password not found. Installing..."
    brew install --cask 1password-cli
  fi
fi
