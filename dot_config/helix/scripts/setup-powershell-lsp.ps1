#Requires -Version 7

$ErrorActionPreference = "Stop"

if (-not $IsWindows) {
    Write-Host "Not Windows, skipping."
    exit 0
}

$installRoot = Join-Path $HOME ".local\share\powershell-editor-services"
$binDir = Join-Path $HOME ".local\bin"

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

Write-Host "Getting latest PowerShell Editor Services release..."

$release = Invoke-RestMethod `
    "https://api.github.com/repos/PowerShell/PowerShellEditorServices/releases/latest"

$asset = $release.assets |
    Where-Object { $_.name -like "*.zip" } |
    Select-Object -First 1

if (-not $asset) {
    throw "Could not find release ZIP"
}

$version = $release.tag_name.TrimStart("v")

$versionDir = Join-Path $installRoot $version
$currentDir = Join-Path $installRoot "current"

if (-not (Test-Path $versionDir)) {

    Write-Host "Downloading $($asset.name)..."

    $guid = [guid]::

    $tempDir = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        "pses-$guid"

    $zipFile = Join-Path $tempDir $asset.name

    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    Invoke-WebRequest `
        -Uri $asset.browser_download_url `
        -OutFile $zipFile

    Expand-Archive `
        -Path $zipFile `
        -DestinationPath $versionDir `
        -Force

    Remove-Item $tempDir -Recurse -Force
}

if (Test-Path $currentDir) {
    Remove-Item $currentDir -Recurse -Force
}

Copy-Item `
    -Path $versionDir `
    -Destination $currentDir `
    -Recurse `
    -Force

$wrapper = Join-Path $binDir "powershell-editor-services.cmd"

@"
@echo off

set PSES=%USERPROFILE%\.local\share\powershell-editor-services\current

pwsh.exe ^
  -NoLogo ^
  -NoProfile ^
  -ExecutionPolicy Bypass ^
  -File "%PSES%\PowerShellEditorServices\Start-EditorServices.ps1" ^
  -HostName Helix ^
  -HostProfileId helix ^
  -HostVersion 1.0 ^
  -BundledModulesPath "%PSES%" ^
  -LogPath "%TEMP%\helix-powershell.log" ^
  -SessionDetailsPath "%TEMP%\helix-powershell.json" ^
  -LanguageServiceOnly ^
  -Stdio
"@ | Set-Content $wrapper -Encoding ASCII

Write-Host ""
Write-Host "Installed PowerShell Editor Services"
Write-Host ""
Write-Host "Wrapper:"
Write-Host "  $wrapper"
Write-Host ""
Write-Host "Ensure ~/.local/bin is on PATH"