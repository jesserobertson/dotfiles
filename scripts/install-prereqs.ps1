# Install winget packages from wingetfile. Run this BEFORE chezmoi apply.
# Mirrors install-prereqs.sh for macOS/Linux.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget not found. Install App Installer from the Microsoft Store."
    exit 1
}

$wingetfile = Join-Path $PSScriptRoot ".." "dot_config" "wingetfile"
$packages = Get-Content $wingetfile |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }

foreach ($id in $packages) {
    if (-not (winget list --id $id --exact 2>$null | Select-String $id -Quiet)) {
        Write-Host "Installing (winget) $id..."
        winget install --id $id --silent --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "Already installed: $id"
    }
}
