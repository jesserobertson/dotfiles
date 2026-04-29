#!/usr/bin/env bash
set -euo pipefail

if ! command -v pixi &>/dev/null; then
    echo "Error: pixi is not installed. Run 'make prereqs' first, then install pixi via brew: brew install pixi" >&2
    exit 1
fi

# Python development environment
pixi global install --environment python python uv ruff mypy

# HTTP utilities (library env, no exposed binaries)
pixi global install --environment requests \
  requests
