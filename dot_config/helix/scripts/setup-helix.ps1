
$ErrorActionPreference = "Stop"

& "$PSScriptRoot\setup-python-tools.ps1"
& "$PSScriptRoot\setup-node-tools.ps1"
& "$PSScriptRoot\setup-powershell-lsp.ps1"

Write-Host ""
Write-Host "Running validation..."
Write-Host ""

hx --health rust
hx --health cpp
hx --health python
hx --health bash
hx --health fish
hx --health powershell
