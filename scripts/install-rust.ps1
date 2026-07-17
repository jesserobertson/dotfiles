# Install rustup + stable/nightly toolchains directly via rustup-init.exe,
# targeting our own CARGO_HOME/RUSTUP_HOME rather than going through scoop's
# rustup package. Mirrors scripts/install-rust.fish's approach: rustup-init
# (whether invoked via sh.rustup.rs on Unix or rustup-init.exe here) reads
# CARGO_HOME/RUSTUP_HOME from the environment at install time on every
# platform, so setting them before invoking it gets a real, portable install
# instead of scoop's package-level env_set hardcoding them to its own
# persist directory (which fights any value we declare here).
#
# Functions below are pure/deterministic and dot-sourceable for Pester
# (see tests/powershell/install-rust.Tests.ps1); the install itself only
# runs when this file is executed directly, not dot-sourced.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RustupTargetTriple {
    <#
    .SYNOPSIS
        Maps a Windows processor architecture to the rustup-init.exe target triple.
    #>
    param([string]$Architecture)
    switch ($Architecture) {
        "ARM64" { "aarch64-pc-windows-msvc" }
        default { "x86_64-pc-windows-msvc" }
    }
}

function Get-DefaultRustHomes {
    <#
    .SYNOPSIS
        Default CARGO_HOME/RUSTUP_HOME — same values .chezmoi.toml.tmpl declares
        for every other shell, so a fresh env has one consistent answer regardless
        of which shell asks first.
    #>
    param([string]$HomeDir = $HOME)
    [PSCustomObject]@{
        CargoHome  = Join-Path $HomeDir ".local" "share" "cargo"
        RustupHome = Join-Path $HomeDir ".local" "share" "rustup"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($env:CI) {
        Write-Host "CI environment detected - skipping Rust installation"
        exit 0
    }

    # Force these to our declared value rather than defaulting-if-unset: on
    # Windows, scoop's rustup package (when installed) sets CARGO_HOME/
    # RUSTUP_HOME as *persistent* user-level environment variables, so a
    # default-if-unset check would see them as "already set" and silently
    # keep using scoop's location - exactly the problem this script exists
    # to avoid. This script is the one place that gets to decide where rust
    # lives; it doesn't inherit that decision from the ambient environment.
    $defaults = Get-DefaultRustHomes
    $env:RUSTUP_HOME = $defaults.RustupHome
    $env:CARGO_HOME  = $defaults.CargoHome
    $cargoBin = Join-Path $env:CARGO_HOME "bin"
    if ($env:PATH -notlike "*$cargoBin*") { $env:PATH = "$cargoBin;$env:PATH" }

    if (-not (Test-Path $cargoBin)) {
        $existingRustup = Get-Command rustup -ErrorAction SilentlyContinue
        if ($existingRustup) {
            Write-Host "rustup found but not in correct location, removing old installation..."
            try { rustup self uninstall -y } catch {}
            if (Get-Command scoop -ErrorAction SilentlyContinue) {
                try { scoop uninstall rustup } catch {}
            }
            Remove-Item -Recurse -Force (Join-Path $HOME ".cargo") -ErrorAction SilentlyContinue
            Remove-Item -Recurse -Force (Join-Path $HOME ".rustup") -ErrorAction SilentlyContinue
        }

        Write-Host "Installing rustup to custom location..."
        $arch = Get-RustupTargetTriple -Architecture $env:PROCESSOR_ARCHITECTURE
        $installerUrl = "https://static.rust-lang.org/rustup/dist/$arch/rustup-init.exe"
        $installerPath = Join-Path ([System.IO.Path]::GetTempPath()) "rustup-init.exe"
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
        # Re-assert immediately before invoking the installer: `scoop uninstall
        # rustup` above has been observed to clear $env:CARGO_HOME/RUSTUP_HOME
        # as part of its own cleanup (it originally set them via env_set), which
        # would otherwise silently undo the override from earlier in this block.
        $env:RUSTUP_HOME = $defaults.RustupHome
        $env:CARGO_HOME  = $defaults.CargoHome
        & $installerPath -y --no-modify-path
        Remove-Item $installerPath -ErrorAction SilentlyContinue
        $env:PATH = "$cargoBin;$env:PATH"
    }

    Write-Host "Checking Rust toolchain..."
    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        if ($env:FORCE -eq "true") {
            Write-Host "Force mode enabled - reinstalling Rust toolchains..."
            try { rustup toolchain uninstall stable } catch {}
            try { rustup toolchain uninstall nightly } catch {}
            rustup toolchain install stable
            rustup toolchain install nightly
        } else {
            $toolchains = rustup toolchain list
            if ($toolchains -notmatch "stable") {
                Write-Host "Installing stable toolchain..."
                rustup toolchain install stable
            } else {
                Write-Host "Stable toolchain already installed"
            }

            if ($toolchains -notmatch "nightly") {
                Write-Host "Installing nightly toolchain..."
                rustup toolchain install nightly
            } else {
                Write-Host "Nightly toolchain already installed"
            }
        }

        Write-Host "Rust toolchain check complete!"
    } else {
        Write-Warning "rustup not found, skipping Rust toolchain installation"
    }
}
