# Windows prerequisites: ensure scoop and core tools are installed.
# Runs before chezmoi applies the rest of the dotfiles.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Scoop ---
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else {
    Write-Host "scoop already installed, skipping."
}

# Ensure shims are on PATH for the rest of this script
$scoopShims = Join-Path $HOME "scoop\shims"
if ($env:PATH -notlike "*$scoopShims*") {
    $env:PATH = "$scoopShims;$env:PATH"
}


