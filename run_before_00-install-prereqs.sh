#!/usr/bin/env bash

set -eu

## INSTALL HOMEBREW 
echo "Installing Homebrew..."

# Detect OS and set up homebrew paths
case "$(uname -s)" in
Darwin)
    echo "Detected macOS"
    OS="darwin"
    # Test for homebrew locations on macOS (Apple Silicon vs Intel)
    if [ -x "/opt/homebrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    elif [ -x "/usr/local/bin/brew" ]; then
        HOMEBREW_PREFIX="/usr/local"
    else
        # Set default for installation
        HOMEBREW_PREFIX="/opt/homebrew"
    fi
    PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
    ;;
Linux)
    echo "Detected Linux"
    OS="linux"
    # Test for homebrew location on Linux
    if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    elif [ -x "${HOME}/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="${HOME}/.linuxbrew"
    else
        # Set default for installation
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
BREW_BIN=$(which brew 2>/dev/null || true)

if [ -n "${BREW_BIN}" ] && [ -x "${BREW_BIN}" ]; then
  echo "Homebrew already installed at ${BREW_BIN}"
else
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Update PATH after installation
  PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
fi

## INSTALL 1PASSWORD (needed for templates, optional in CI)
# Detect if we're in CI environment
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ]; then
  echo "CI environment detected, skipping 1Password CLI installation"
  echo "Note: Templates requiring 1Password will be ignored via .chezmoiignore"
else
  echo "Checking for 1Password CLI (op)"
  OP_BIN=$(which op 2>/dev/null || true)

  if [ -n "${OP_BIN}" ] && [ -x "${OP_BIN}" ]; then
    echo "1Password (op) already installed at ${OP_BIN}"
  else
    echo "1Password not found. Installing..."
    brew install 1password-cli
  fi
fi
