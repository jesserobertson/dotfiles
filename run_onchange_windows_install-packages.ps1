# Install all packages listed in ~/.config/scoopfile and ~/.config/wingetfile
# Re-runs whenever this file changes (triggered by chezmoi when scoopfile/wingetfile change)

# --- Scoop ---
$scoopfile = Join-Path $HOME ".config" "scoopfile"
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    $packages = Get-Content $scoopfile |
        Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }
    foreach ($pkg in $packages) {
        $name = ($pkg -split '/') | Select-Object -Last 1
        if (-not (scoop list $name 2>$null | Select-String $name -Quiet)) {
            Write-Host "Installing (scoop) $pkg..."
            scoop install $pkg
        }
    }
} else {
    Write-Host "scoop not found, skipping scoopfile install"
}

# --- WinGet ---
$wingetfile = Join-Path $HOME ".config" "wingetfile"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $packages = Get-Content $wingetfile |
        Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }
    foreach ($id in $packages) {
        $installed = winget list --id $id --exact 2>$null | Select-String $id -Quiet
        if (-not $installed) {
            Write-Host "Installing (winget) $id..."
            winget install --id $id --silent --accept-package-agreements --accept-source-agreements
        }
    }
} else {
    Write-Host "winget not found, skipping wingetfile install"
}
