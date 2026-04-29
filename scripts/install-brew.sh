#!/bin/bash
set -euo pipefail

echo "Installing Homebrew packages..."

case "$(uname -s)" in
Darwin)
    if [ -x "/opt/homebrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    elif [ -x "/usr/local/bin/brew" ]; then
        HOMEBREW_PREFIX="/usr/local"
    else
        HOMEBREW_PREFIX="/opt/homebrew"
    fi
    ;;
Linux)
    if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    elif [ -x "${HOME}/.linuxbrew/bin/brew" ]; then
        HOMEBREW_PREFIX="${HOME}/.linuxbrew"
    else
        HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    fi
    ;;
*)
    echo "Unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

export PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"
echo "Using Homebrew prefix: ${HOMEBREW_PREFIX}"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BREWFILE="${XDG_CONFIG_HOME}/brewfile"
echo "Installing packages from ${BREWFILE}..."

if [ "${FORCE:-false}" = "true" ]; then
    echo "Force mode enabled - reinstalling all packages..."
    brew bundle install --force --file="${BREWFILE}" --verbose
else
    brew bundle install --file="${BREWFILE}" --verbose
fi

echo "Homebrew package installation complete!"
