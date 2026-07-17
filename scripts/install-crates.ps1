# Install Rust crates from packages/cratefile.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($env:CI) {
    Write-Host "CI environment detected - skipping Rust crate installation"
    exit 0
}

# Force these to our declared value rather than defaulting-if-unset: on
# Windows, scoop's rustup package (if ever installed) sets CARGO_HOME as a
# *persistent* user-level environment variable, so a default-if-unset check
# would see it as "already set" and silently use scoop's location instead
# (see scripts/install-rust.ps1, which installs rust without scoop for
# exactly this reason).
$env:CARGO_HOME  = Join-Path $HOME ".local" "share" "cargo"
$env:RUSTUP_HOME = Join-Path $HOME ".local" "share" "rustup"
$cargoBin = Join-Path $env:CARGO_HOME "bin"
if ($env:PATH -notlike "*$cargoBin*") { $env:PATH = "$cargoBin;$env:PATH" }

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Error "cargo not found. Ensure Rust is installed first (make rust, or run scripts/install-rust.ps1)"
    exit 1
}

$cratesFile = Join-Path $PSScriptRoot ".." "packages" "cratefile"
if (-not (Test-Path $cratesFile)) {
    Write-Error "Crates file not found at $cratesFile"
    exit 1
}

$crates = Get-Content $cratesFile |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' } |
    ForEach-Object { ($_ -split '#')[0].Trim() } |
    Where-Object { $_ }

if (-not $crates) {
    Write-Host "No crates to install"
    exit 0
}

Write-Host "Installing Rust crates..."
$installed = cargo install --list 2>$null

foreach ($crate in $crates) {
    $name = ($crate -split '@')[0]
    if ($env:FORCE -eq "true") {
        Write-Host "Reinstalling $crate..."
        cargo install --force $crate
    } elseif ($installed -like "$name v*") {
        Write-Host "Already installed: $name"
    } else {
        Write-Host "Installing $crate..."
        cargo install $crate
    }
}

Write-Host "Rust crates installation complete!"
