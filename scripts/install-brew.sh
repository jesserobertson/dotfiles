#!/bin/bash
set -euo pipefail

echo "Installing Homebrew packages..."

CHEZMOI_BIN="${CHEZMOI_BIN:-chezmoi}"

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE_TEMPLATE="${SCRIPT_DIR}/../packages/brewfile.tmpl"
BREWFILE_PROCESSED="$(mktemp "${TMPDIR:-/tmp}/brewfile.XXXXXX")"
trap 'rm -f "$BREWFILE_PROCESSED"' EXIT

# Remove stale third-party taps pre-installed by CI runners that Homebrew 4.x
# now flags as untrusted (awscli is in Homebrew core; aws/tap is redundant).
if [ -n "${CI:-}" ]; then
    brew untap aws/tap 2>/dev/null || true
fi

echo "Processing Brewfile template..."
"$CHEZMOI_BIN" execute-template < "$BREWFILE_TEMPLATE" > "$BREWFILE_PROCESSED"
echo "Installing packages from ${BREWFILE_TEMPLATE}..."

if [ "${FORCE:-false}" = "true" ]; then
    echo "Force mode enabled - reinstalling all packages..."
    brew bundle install --force --file="${BREWFILE_PROCESSED}" --verbose
else
    brew bundle install --file="${BREWFILE_PROCESSED}" --verbose
fi

echo "Homebrew package installation complete!"
