#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping pixi global sync"
    exit 0
end

echo "Syncing pixi global environments..."

if not type -q pixi
    echo "Error: pixi not found. Please ensure pixi is installed via Homebrew."
    echo "Run: brew install pixi"
    exit 1
end

pixi global sync

echo "Pixi global sync complete!"
echo ""
echo "Python tools have been installed globally via pixi"
echo "Available commands:"
echo "  - python / python3"
echo "  - ipython"
echo "  - jupyter / jupyter-lab"
echo "  - marimo"
echo "  - ruff"
echo "  - pyright"
echo "  - mypy"
echo ""
echo "To add more packages, edit: ~/.pixi/manifests/pixi-global.toml"
echo "Then run: pixi global sync"
