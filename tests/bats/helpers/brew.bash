#!/usr/bin/env bash
# Shared helpers for bats tests that need Homebrew or bats assertion libraries.
# Load with: load helpers/brew

# Load bats-support and bats-assert from the first location they're found:
# 1. /usr/local/lib/ — installed in Docker image at build time
# 2. $HOMEBREW_PREFIX/lib/ — installed via `brew install bats-core bats-support bats-assert`
_load_bats_libs() {
    local found=0
    for d in /usr/local/lib "${HOMEBREW_PREFIX:-/opt/homebrew}/lib" /home/linuxbrew/.linuxbrew/lib; do
        [ -f "$d/bats-support/load.bash" ] || continue
        load "$d/bats-support/load.bash"
        [ -f "$d/bats-assert/load.bash" ] && load "$d/bats-assert/load.bash"
        found=1
        break
    done
    [ "$found" -eq 0 ] && echo "# bats-support/bats-assert not found — assert_* helpers unavailable" >&3 || true
}
_load_bats_libs

# Finds and activates Homebrew in the current shell so subsequent test
# commands can call `brew` and any Homebrew-installed binaries.
# Call this in setup_file() for tests that require Homebrew.
setup_brew_env() {
    for bp in \
        /home/linuxbrew/.linuxbrew/bin/brew \
        /opt/homebrew/bin/brew \
        /usr/local/bin/brew; do
        [ -x "$bp" ] || continue
        eval "$($bp shellenv)"
        return 0
    done
    echo "# WARNING: Homebrew not found — brew tests will fail" >&3
}
