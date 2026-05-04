# Install all packages listed in ~/.config/scoopfile
# Runs once on chezmoi init; re-runs if this file changes

$scoopfile = Join-Path $HOME ".config" "scoopfile"
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "scoop not found, skipping scoopfile install"
    exit 0
}

$packages = Get-Content $scoopfile |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }

foreach ($pkg in $packages) {
    $name = ($pkg -split '/') | Select-Object -Last 1
    if (-not (scoop list $name 2>$null | Select-String $name -Quiet)) {
        Write-Host "Installing $pkg..."
        scoop install $pkg
    }
}
