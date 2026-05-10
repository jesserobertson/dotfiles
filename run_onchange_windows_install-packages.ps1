# Bootstrap scoop and install scoop packages from scoopfile.
# Winget packages are handled by scripts/install-prereqs.ps1 (run before chezmoi apply).
# Re-runs whenever this file changes (triggered by chezmoi when scoopfile changes).

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Ensure SCOOP points to our XDG-friendly location BEFORE the installer runs,
# so scoop installs there rather than the default ~/scoop.
if (-not $env:SCOOP) {
    $env:SCOOP = Join-Path $HOME ".local" "scoop"
}

# --- Bootstrap scoop ---
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

$scoopShims = Join-Path $env:SCOOP "shims"
if ($env:PATH -notlike "*$scoopShims*") {
    $env:PATH = "$scoopShims;$env:PATH"
}

# --- Scoop packages ---
$scoopfile = Join-Path $HOME ".config" "scoopfile"
$packages = Get-Content $scoopfile |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }
foreach ($pkg in $packages) {
    $name = ($pkg -split '/') | Select-Object -Last 1
    if (-not (scoop list $name 2>$null | Select-String $name -Quiet)) {
        Write-Host "Installing (scoop) $pkg..."
        scoop install $pkg
    }
}
