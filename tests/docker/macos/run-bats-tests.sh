#!/usr/bin/env bash
set -e

for bp in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew /usr/local/bin/brew; do
    [ -x "$bp" ] && eval "$($bp shellenv)" && break
done

echo ""
echo "=== Running bats tests ==="
bats /dotfiles-source/tests/bats/install.bats
