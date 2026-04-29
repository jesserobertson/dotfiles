#!/usr/bin/env bash
set -euo pipefail

# Python development environment
pixi global install --environment python python uv ruff mypy

# HTTP utilities (library env, no exposed binaries)
pixi global install --environment requests \
  requests
