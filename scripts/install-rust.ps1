# Install rustup + stable/nightly toolchains directly via rustup-init.exe,
# targeting our own CARGO_HOME/RUSTUP_HOME rather than going through scoop's
# rustup package. Mirrors scripts/install-rust.fish's approach: rustup-init
# (whether invoked via sh.rustup.rs on Unix or rustup-init.exe here) reads
# CARGO_HOME/RUSTUP_HOME from the environment at install time on every
# platform, so setting them before invoking it gets a real, portable install
# instead of scoop's package-level env_set hardcoding them to its own
# persist directory (which fights any value we declare here).
#
# Functions below are dot-sourceable for Pester (the pure ones are
# unit-tested; see tests/powershell/install-rust.Tests.ps1); the install
# itself only runs when this file is executed directly, not dot-sourced.

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

function Test-ToolchainInstalled {
    <#
    .SYNOPSIS
        Is $Channel present in `rustup toolchain list` output?

        Anchored to the start of each line on purpose: `rustup toolchain list`
        emits "<channel>-<target> [(active, default)]" per line, so a bare
        `$list -notmatch $channel` (the array-filtering form of -notmatch,
        which returns the non-matching elements rather than a bool) reported
        every toolchain as "missing" and reinstalled them all on every run.
    #>
    param(
        [string[]]$ToolchainList,
        [Parameter(Mandatory)][string]$Channel
    )
    $pattern = "^{0}(-|\s|$)" -f [regex]::Escape($Channel)
    [bool](@($ToolchainList) -match $pattern)
}

function Invoke-RustupInstall {
    <#
    .SYNOPSIS
        Run `rustup toolchain install $Channel`, streaming rustup's own output
        to the console/log while printing a heartbeat every $HeartbeatSeconds.

        rustup shows a progress bar for the download but goes silent for
        minutes during the verify/unpack phase (rust-docs alone is tens of
        thousands of files), which reads as a hang. The heartbeat proves it
        is still alive. Start-Process ignores $ErrorActionPreference, so a
        non-zero exit is turned back into a terminating error by hand.
    #>
    param(
        [Parameter(Mandatory)][string]$Channel,
        [int]$HeartbeatSeconds = 20
    )
    Write-Host "==> rustup toolchain install $Channel"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = Start-Process -FilePath "rustup" `
        -ArgumentList "toolchain", "install", $Channel `
        -NoNewWindow -PassThru
    while (-not $proc.HasExited) {
        Start-Sleep -Seconds $HeartbeatSeconds
        if (-not $proc.HasExited) {
            Write-Host ("    ... still working ({0:mm\:ss} elapsed)" -f $sw.Elapsed)
        }
    }
    $proc.WaitForExit()
    $sw.Stop()
    if ($proc.ExitCode -ne 0) {
        throw "rustup toolchain install $Channel exited with code $($proc.ExitCode) after $($sw.Elapsed)"
    }
    Write-Host ("    done ({0:mm\:ss})" -f $sw.Elapsed)
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
            Invoke-RustupInstall -Channel "stable"
            Invoke-RustupInstall -Channel "nightly"
        } else {
            $toolchains = @(rustup toolchain list)
            foreach ($channel in "stable", "nightly") {
                if (Test-ToolchainInstalled -ToolchainList $toolchains -Channel $channel) {
                    Write-Host "$channel toolchain already installed"
                } else {
                    Write-Host "Installing $channel toolchain..."
                    Invoke-RustupInstall -Channel $channel
                }
            }
        }

        Write-Host "Rust toolchain check complete!"
    } else {
        Write-Warning "rustup not found, skipping Rust toolchain installation"
    }
}
