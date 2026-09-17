
$Failed = $false

function Ok($msg) {
    Write-Host "✅ $msg" -ForegroundColor Green
}

function Warn($msg) {
    Write-Host "⚠️  $msg" -ForegroundColor Yellow
}

function Fail($msg) {
    Write-Host "❌ $msg" -ForegroundColor Red
    $script:Failed = $true
}

function Test-Cmd($Name) {

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue

    if ($cmd) {
        Ok "$Name -> $($cmd.Source)"
    }
    else {
        Fail "$Name not found"
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "Helix Doctor"
Write-Host "========================================"
Write-Host ""

#
# Core
#

Test-Cmd hx

if (Get-Command hx -ErrorAction SilentlyContinue) {
    hx --version
}

#
# Rust
#

Write-Host ""
Write-Host "--- Rust ---"

Test-Cmd rustup
Test-Cmd cargo
Test-Cmd rust-analyzer
Test-Cmd rustfmt
Test-Cmd cargo-clippy

if (Get-Command rustup -ErrorAction SilentlyContinue) {
    rustup show active-toolchain
}

#
# LLVM
#

Write-Host ""
Write-Host "--- LLVM / C++ ---"

Test-Cmd clang
Test-Cmd clangd
Test-Cmd clang-format

Write-Host ""
Write-Host "All clangd executables:"

Get-Command clangd -All -ErrorAction SilentlyContinue |
    Select-Object Source

$llvmEntries =
    $env:PATH -split ';' |
    Where-Object { $_ -match 'llvm' }

if ($llvmEntries.Count -gt 1) {
    Warn "Multiple LLVM paths found:"
    $llvmEntries
}

#
# Python
#

Write-Host ""
Write-Host "--- Python ---"

Test-Cmd python
Test-Cmd pixi
Test-Cmd ruff
Test-Cmd basedpyright-langserver

if (Get-Command python -ErrorAction SilentlyContinue) {
    python --version
}

#
# Shells
#

Write-Host ""
Write-Host "--- Shells ---"

Test-Cmd bash
Test-Cmd fish

Test-Cmd bash-language-server
Test-Cmd fish-lsp

#
# PowerShell
#

Write-Host ""
Write-Host "--- PowerShell ---"

Test-Cmd pwsh

if (Get-Command powershell-editor-services -ErrorAction SilentlyContinue) {
    Ok "powershell-editor-services wrapper detected"
}
else {
    Warn "powershell-editor-services wrapper missing"
}

#
# Helix health
#

if (Get-Command hx -ErrorAction SilentlyContinue) {

    Write-Host ""
    Write-Host "--- hx --health rust ---"
    hx --health rust

    Write-Host ""
    Write-Host "--- hx --health cpp ---"
    hx --health cpp

    Write-Host ""
    Write-Host "--- hx --health python ---"
    hx --health python

    Write-Host ""
    Write-Host "--- hx --health bash ---"
    hx --health bash

    Write-Host ""
    Write-Host "--- hx --health fish ---"
    hx --health fish

    Write-Host ""
    Write-Host "--- hx --health powershell ---"
    hx --health powershell
}

#
# Final result
#

Write-Host ""
Write-Host "========================================"

if ($Failed) {
    Write-Host "❌ Problems detected" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "✅ Helix environment healthy" -ForegroundColor Green
    exit 0
}
