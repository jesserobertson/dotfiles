#!/usr/bin/env bash
set -e

for bp in /home/linuxbrew/.linuxbrew/bin/brew /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$bp" ] && eval "$($bp shellenv)" && break
done

echo ""
echo "=== Running bats tests ==="
bats /dotfiles-source/tests/bats/install.bats \
     /dotfiles-source/tests/bats/shell-env.bats \
     /dotfiles-source/tests/bats/fish.bats
