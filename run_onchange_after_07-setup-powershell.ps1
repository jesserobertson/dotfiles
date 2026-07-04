# Wire the PowerShell $PROFILE to the chezmoi-managed file.
# chezmoi deploys the profile to ~/.config/powershell/profile.ps1
# This creates the $PROFILE directory and dot-sources the managed file.

if (-not $IsWindows) { Write-Host "Not Windows, skipping."; exit 0 }

$managedProfile = Join-Path $HOME ".config\powershell\profile.ps1"
$sourceLine = ". `"$managedProfile`""

$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (-not (Test-Path $PROFILE)) {
    Set-Content -Path $PROFILE -Value $sourceLine
} elseif (-not (Select-String -Path $PROFILE -SimpleMatch $managedProfile -Quiet)) {
    Add-Content -Path $PROFILE -Value "`n$sourceLine"
}
Write-Host "PowerShell profile wired to $managedProfile"
