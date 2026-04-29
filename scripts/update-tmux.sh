#!/usr/bin/env bash
set -euo pipefail

TPM_DIR="$HOME/.config/tmux/plugins/tpm"

if [ "${FORCE:-false}" = "true" ]; then
    echo "Force mode enabled - removing existing TPM installation..."
    rm -rf "$TPM_DIR"
fi

if [ -d "$TPM_DIR" ]; then
    echo "TPM already installed at $TPM_DIR"
    exit 0
fi

echo "Installing tmux plugin manager..."
git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
echo "TPM installed successfully"
