
#!/usr/bin/env fish

set -g failed 0

function ok
    echo "✅ $argv"
end

function warn
    echo "⚠️  $argv"
end

function fail
    echo "❌ $argv"
    set -g failed 1
end

function check_cmd
    set cmd $argv[1]

    if command -sq $cmd
        ok "$cmd: "(command -v $cmd)
    else
        fail "$cmd not found"
    end
end

echo
echo "========================================"
echo "Helix Doctor"
echo "========================================"
echo

#
# Core
#

check_cmd hx

if command -sq hx
    echo
    hx --version
end

#
# Rust
#

echo
echo "--- Rust ---"

check_cmd rustup
check_cmd cargo
check_cmd rust-analyzer
check_cmd rustfmt
check_cmd cargo-clippy

if command -sq rustup
    echo "Toolchain:"
    rustup show active-toolchain
end

#
# LLVM / C++
#

echo
echo "--- LLVM / C++ ---"

check_cmd clang
check_cmd clangd
check_cmd clang-format

if type -a clangd >/dev/null 2>&1
    echo
    echo "clangd locations:"
    type -a clangd
end

#
# Python
#

echo
echo "--- Python ---"

check_cmd python
check_cmd pixi
check_cmd ruff
check_cmd basedpyright-langserver

if command -sq python
    python --version
end

#
# Shells
#

echo
echo "--- Shells ---"

check_cmd bash
check_cmd fish

check_cmd bash-language-server
check_cmd fish-lsp

#
# PowerShell
#

echo
echo "--- PowerShell ---"

check_cmd pwsh

if command -sq powershell-editor-services
    ok "powershell-editor-services found"
else
    warn "powershell-editor-services wrapper not found"
end

#
# Helix health
#

if command -sq hx

    echo
    echo "--- hx --health rust ---"
    hx --health rust

    echo
    echo "--- hx --health cpp ---"
    hx --health cpp

    echo
    echo "--- hx --health python ---"
    hx --health python

    echo
    echo "--- hx --health bash ---"
    hx --health bash

    echo
    echo "--- hx --health fish ---"
    hx --health fish

    echo
    echo "--- hx --health powershell ---"
    hx --health powershell

end

#
# Summary
#

echo
echo "========================================"

if test $failed -eq 0
    echo "✅ Helix environment looks healthy"
    exit 0
else
    echo "❌ Issues detected"
    exit 1
end
