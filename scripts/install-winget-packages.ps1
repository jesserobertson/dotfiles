# Manual winget bootstrap helper. Run once on a new Windows machine.
# Already-installed packages are skipped (winget is idempotent).

if (-not $IsWindows) { Write-Host "Not Windows, skipping."; exit 0 }

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$wingetfile = Join-Path $HOME ".config\wingetfile"
if (-not (Test-Path $wingetfile)) {
    Write-Host "No wingetfile found at $wingetfile"
    exit 1
}

Write-Host "Installing winget packages from $wingetfile..."

$failed = @()
Get-Content $wingetfile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    Write-Host "Installing $line..."
    winget install --id $line --exact --accept-source-agreements --accept-package-agreements
    $alreadyInstalled = -1978335189
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $alreadyInstalled) {
        $failed += $line
    }
}

if ($failed.Count -gt 0) {
    Write-Warning "Failed to install: $($failed -join ', ')"
    exit 1
}
Write-Host "Winget package installation complete!"
