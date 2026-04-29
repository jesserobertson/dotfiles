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

# --- Core scoop buckets ---
$buckets = @("extras", "versions")
foreach ($bucket in $buckets) {
    if (-not (scoop bucket list | Select-String $bucket -Quiet)) {
        Write-Host "Adding scoop bucket: $bucket"
        scoop bucket add $bucket
    }
}

# --- 1Password CLI ---
if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
    Write-Host "Installing 1Password CLI..."
    scoop install extras/1password-cli
} else {
    Write-Host "1Password CLI (op) already installed, skipping."
}

# --- oh-my-posh ---
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Host "Installing oh-my-posh..."
    scoop install main/oh-my-posh
} else {
    Write-Host "oh-my-posh already installed, skipping."
}
