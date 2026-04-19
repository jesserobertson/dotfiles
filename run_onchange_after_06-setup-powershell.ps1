# Wire the PowerShell profile to the chezmoi-managed file.
# chezmoi deploys the template to ~/.config/powershell/profile.ps1
# This script creates the directory for $PROFILE and adds a dot-source line
# pointing at the managed file, if it's not already there.

if (-not $IsWindows) { Write-Host "Not Windows, skipping."; exit 0 }

$managedProfile = Join-Path $HOME ".config\powershell\profile.ps1"
$sourceLine = ". `"$managedProfile`""

# Create the $PROFILE directory if needed
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Create $PROFILE if it doesn't exist, or add the source line if missing
if (-not (Test-Path $PROFILE)) {
    Set-Content -Path $PROFILE -Value $sourceLine
} elseif (-not (Select-String -Path $PROFILE -SimpleMatch $managedProfile -Quiet)) {
    Add-Content -Path $PROFILE -Value "`n$sourceLine"
}
