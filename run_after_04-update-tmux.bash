#!/usr/bin/env bash
set -euo pipefail
# Updated to trigger chezmoi

TPM_DIR="$HOME/.config/tmux/plugins/tpm"

# Check if force mode is enabled via environment variable
if [ "${FORCE:-false}" = "true" ]; then
    echo "Force mode enabled - removing existing TPM installation..."
    rm -rf "$TPM_DIR"
fi

# Check if TPM is already installed
if [ -d "$TPM_DIR" ]; then
    echo "TPM already installed at $TPM_DIR"
    exit 0
fi

# Install TPM
echo "Installing tmux plugin manager..."
git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
echo "TPM installed successfully"
