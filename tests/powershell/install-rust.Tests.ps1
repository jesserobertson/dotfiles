#Requires -Module Pester
<#
    Unit tests for scripts/install-rust.ps1's pure/deterministic logic.
    The script only runs its actual install (network calls, rustup-init.exe,
    toolchain installs) when invoked directly — dot-sourcing it here (as
    Pester does to reach the functions) leaves that guarded and skipped.
    Run with: Invoke-Pester tests/powershell/install-rust.Tests.ps1
#>

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\scripts\install-rust.ps1'
    . $scriptPath
}

Describe 'Get-RustupTargetTriple' {
    It 'returns the aarch64 triple for ARM64' {
        Get-RustupTargetTriple -Architecture 'ARM64' | Should -Be 'aarch64-pc-windows-msvc'
    }

    It 'returns the x86_64 triple for AMD64' {
        Get-RustupTargetTriple -Architecture 'AMD64' | Should -Be 'x86_64-pc-windows-msvc'
    }

    It 'defaults to the x86_64 triple for an unrecognized architecture' {
        Get-RustupTargetTriple -Architecture 'RISCV64' | Should -Be 'x86_64-pc-windows-msvc'
    }

    It 'defaults to the x86_64 triple for an empty architecture' {
        Get-RustupTargetTriple -Architecture '' | Should -Be 'x86_64-pc-windows-msvc'
    }
}

Describe 'Get-DefaultRustHomes' {
    It 'defaults CargoHome to .local/share/cargo under the given home' {
        (Get-DefaultRustHomes -HomeDir 'C:\Users\test').CargoHome | Should -Be 'C:\Users\test\.local\share\cargo'
    }

    It 'defaults RustupHome to .local/share/rustup under the given home' {
        (Get-DefaultRustHomes -HomeDir 'C:\Users\test').RustupHome | Should -Be 'C:\Users\test\.local\share\rustup'
    }

    It 'uses $HOME when no home directory is given' {
        (Get-DefaultRustHomes).CargoHome | Should -Be (Join-Path $HOME '.local' 'share' 'cargo')
    }

    It 'never defaults to the bare .cargo/.rustup dirs (regression check)' {
        # scripts/install-crates.ps1 previously had RUSTUP_HOME fall back to
        # "$HOME/.rustup" instead of "$HOME/.local/share/rustup" - a copy-paste
        # bug that silently diverged from what this script (and .chezmoi.toml.tmpl)
        # actually use. Lock in the correct value so that class of bug can't recur.
        $defaults = Get-DefaultRustHomes -HomeDir 'C:\Users\test'
        $defaults.CargoHome  | Should -Not -Be 'C:\Users\test\.cargo'
        $defaults.RustupHome | Should -Not -Be 'C:\Users\test\.rustup'
    }
}

Describe 'install-rust.ps1 dot-source safety' {
    It 'defines its functions without running the install' {
        # If dot-sourcing had run the install body, this test process would have
        # made a real network call and likely thrown (no admin/network in CI) or
        # hung - reaching this assertion at all is the real check.
        Get-Command Get-RustupTargetTriple -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Get-Command Get-DefaultRustHomes -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}
