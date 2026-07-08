# Wire the PowerShell $PROFILE to the chezmoi-managed file.
# chezmoi deploys the real config to ~/.config/powershell/profile.ps1 via template.
# $PROFILE lives in a user-specific location (e.g. OneDrive\Documents), so we write
# it here rather than trying to manage the path in chezmoi's source directory.
# Only appends the source line if missing, rather than overwriting $PROFILE outright,
# so re-running this doesn't clobber anything else already in the file.

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
