$ErrorActionPreference = "Stop"

Write-Host "Installing Helix node-based language servers..."

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "npm not found. Install nodejs-lts first."
}

npm install --global `
    bash-language-server `
    fish-lsp

Write-Host "Verifying..."

Get-Command bash-language-server -ErrorAction Stop | Out-Null

# fish-lsp binary name depends on package version
if (-not (Get-Command fish-lsp -ErrorAction SilentlyContinue)) {
    Write-Warning "fish-lsp not currently on PATH"
}

Write-Host "Node language servers installed"
