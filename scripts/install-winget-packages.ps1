# Manual winget bootstrap helper.
# Run this script once when setting up a new Windows machine.
# winget install is idempotent — already-installed packages are skipped.

if (-not $IsWindows) { Write-Host "Not Windows, skipping."; exit 0 }

$wingetfile = Join-Path $HOME ".config\wingetfile"
if (-not (Test-Path $wingetfile)) {
    Write-Host "No wingetfile found at $wingetfile"
    exit 1
}

Write-Host "Installing winget packages from $wingetfile..."

Get-Content $wingetfile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    Write-Host "Installing $line..."
    winget install --id $line --accept-source-agreements --accept-package-agreements
}

Write-Host "Winget package installation complete!"
