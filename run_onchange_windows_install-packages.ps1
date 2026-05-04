# Bootstrap scoop, then install all packages from scoopfile and wingetfile.
# Re-runs whenever this file changes (triggered by chezmoi when scoopfile/wingetfile change).

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Bootstrap scoop ---
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

$scoopShims = Join-Path $HOME "scoop\shims"
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

# --- WinGet packages ---
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $wingetfile = Join-Path $HOME ".config" "wingetfile"
    $packages = Get-Content $wingetfile |
        Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }
    foreach ($id in $packages) {
        if (-not (winget list --id $id --exact 2>$null | Select-String $id -Quiet)) {
            Write-Host "Installing (winget) $id..."
            winget install --id $id --silent --accept-package-agreements --accept-source-agreements
        }
    }
} else {
    Write-Host "winget not found, skipping wingetfile install"
}
