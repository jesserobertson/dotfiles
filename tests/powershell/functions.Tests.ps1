#Requires -Module Pester
<#
    Unit tests for dot_config/powershell/functions.psm1
    Run with: Invoke-Pester tests/powershell/functions.Tests.ps1
#>

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\dot_config\powershell\functions.psm1'
    Import-Module $modulePath -Force
}

Describe 'Add-EnvPath' {
    BeforeEach {
        $script:originalPath = $env:PATH
    }
    AfterEach {
        $env:PATH = $script:originalPath
    }

    It 'prepends a new path to PATH' {
        $newPath = 'C:\TestDir\bin'
        Add-EnvPath $newPath
        $env:PATH | Should -Match ([regex]::Escape($newPath))
        $env:PATH | Should -BeLike "$newPath;*"
    }

    It 'does not add a duplicate path' {
        $newPath = 'C:\TestDir\bin'
        Add-EnvPath $newPath
        Add-EnvPath $newPath
        $count = ($env:PATH -split ';' | Where-Object { $_ -ieq $newPath }).Count
        $count | Should -Be 1
    }

    It 'is case-insensitive when checking for duplicates' {
        Add-EnvPath 'C:\TestDir\Bin'
        Add-EnvPath 'C:\testdir\bin'
        $count = ($env:PATH -split ';' | Where-Object { $_ -ieq 'C:\TestDir\Bin' }).Count
        $count | Should -Be 1
    }

    It 'preserves existing PATH entries' {
        $existingEntries = $env:PATH
        Add-EnvPath 'C:\NewTool\bin'
        foreach ($entry in ($existingEntries -split ';')) {
            $env:PATH | Should -Match ([regex]::Escape($entry))
        }
    }
}

Describe 'Set-EnvDefault' {
    BeforeEach {
        # Use a test-scoped variable name to avoid collisions
        $script:testVar = 'PESTER_TEST_VAR'
        Remove-Item "env:$($script:testVar)" -ErrorAction SilentlyContinue
    }
    AfterEach {
        Remove-Item "env:$($script:testVar)" -ErrorAction SilentlyContinue
    }

    It 'sets the variable when not already defined' {
        Set-EnvDefault $script:testVar @('C:\foo', 'bar')
        (Get-Item "env:$($script:testVar)").Value | Should -Be 'C:\foo\bar'
    }

    It 'returns the resulting value' {
        $result = Set-EnvDefault $script:testVar @('C:\foo', 'bar')
        $result | Should -Be 'C:\foo\bar'
    }

    It 'does not overwrite an existing value' {
        $env:PESTER_TEST_VAR = 'already-set'
        Set-EnvDefault $script:testVar @('C:\foo', 'bar')
        (Get-Item "env:$($script:testVar)").Value | Should -Be 'already-set'
    }

    It 'returns the existing value when already set' {
        $env:PESTER_TEST_VAR = 'already-set'
        $result = Set-EnvDefault $script:testVar @('C:\foo', 'bar')
        $result | Should -Be 'already-set'
    }

    It 'joins multiple path segments correctly' {
        Set-EnvDefault $script:testVar @('C:\base', 'sub', 'leaf')
        (Get-Item "env:$($script:testVar)").Value | Should -Be 'C:\base\sub\leaf'
    }
}

Describe 'Set-LocationButBetter' {
    BeforeAll {
        # Use a real temp path — $TestDrive uses a Pester PSDrive that Resolve-Path won't traverse
        $script:testRoot = Join-Path $env:TEMP "pester-nav-$([System.IO.Path]::GetRandomFileName())"
        New-Item -ItemType Directory -Path "$script:testRoot\a\b\c" -Force | Out-Null
        New-Item -ItemType File     -Path "$script:testRoot\a\file.txt" -Force | Out-Null
        # Resolve to long/canonical path so it matches what Resolve-Path returns inside
        # Set-LocationButBetter (on CI, $env:TEMP may return a short 8.3 path like RUNNER~1)
        $script:testRoot = (Resolve-Path $script:testRoot).Path
        $global:__zoxide_initialized = $false   # disable zoxide integration
    }
    AfterAll {
        Remove-Item $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    BeforeEach {
        $script:savedLocation = (Get-Location).Path
        # Drain the default location stack — Set-LocationButBetter uses Push-Location
        # internally and those entries survive between tests otherwise
        for ($i = 0; $i -lt 20; $i++) {
            $prev = (Get-Location).Path
            Pop-Location -ErrorAction SilentlyContinue
            if ((Get-Location).Path -eq $prev) { break }
        }
        Set-Location $script:testRoot
    }
    AfterEach {
        Set-Location $script:savedLocation
    }

    It 'navigates to a given directory' {
        Set-LocationButBetter "$script:testRoot\a\b"
        (Get-Location).Path | Should -Be "$script:testRoot\a\b"
    }

    It 'navigates to parent with dotdot (...)' {
        Set-Location "$script:testRoot\a\b\c"
        Set-LocationButBetter '...'          # 3 dots = 2 levels up
        (Get-Location).Path | Should -Be "$script:testRoot\a"
    }

    It 'goes back with dash (-)' {
        # Use the function itself to push so the stack state is known
        Set-LocationButBetter "$script:testRoot\a"   # pushes testRoot, goes to 'a'
        Set-LocationButBetter '-'                    # pops back to testRoot
        (Get-Location).Path | Should -Be $script:testRoot
    }

    It 'navigates to a file''s parent directory' {
        Set-LocationButBetter "$script:testRoot\a\file.txt"
        (Get-Location).Path | Should -Be "$script:testRoot\a"
    }

    It 'writes an error for a non-existent path' {
        { Set-LocationButBetter "$script:testRoot\does-not-exist" } | Should -Not -Throw
        (Get-Location).Path | Should -Be $script:testRoot
    }

    It 'goes to HOME when called with no arguments' {
        Set-LocationButBetter
        (Get-Location).Path | Should -Be $HOME
    }
}

Describe 'Switch-Prompt' {
    BeforeAll {
        # Minimal prompt scaffolding; avoid calling Set-ShellIntegration
        $global:Prompts = @{
            Current      = 'Simple'
            Original     = { 'original>' }
            Simple       = { 'simple>' }
            Starship     = { 'starship>' }
            StarshipShort = { 'short>' }
        }
        $global:term_app = 'WindowsTerminal'  # must be a ValidateSet value for Set-ShellIntegration
        Mock -ModuleName functions Set-ShellIntegration {}   # stub out terminal escape codes
    }
    AfterEach {
        $global:Prompts.Current = 'Simple'
    }

    It 'switches to a named prompt' {
        Switch-Prompt -Prompt Starship
        $global:Prompts.Current | Should -Be 'Starship'
    }

    It 'updates the active prompt function' {
        Switch-Prompt -Prompt Simple
        $function:prompt.ToString() | Should -BeLike "*simple>*"
    }

    It 'cycles to the next prompt when no name given' {
        $global:Prompts.Current = 'Simple'
        Switch-Prompt
        $global:Prompts.Current | Should -Not -Be 'Simple'
    }

    It 'wraps around when at the last prompt' {
        [array]$keys = $global:Prompts.Keys | Where-Object { $_ -ne 'Current' }
        $global:Prompts.Current = $keys[-1]
        Switch-Prompt
        $global:Prompts.Current | Should -Be $keys[0]
    }

    It 'skips Set-ShellIntegration when -NoShellIntegration is passed' {
        Switch-Prompt -Prompt Simple -NoShellIntegration
        Should -Invoke -ModuleName functions Set-ShellIntegration -Times 0
    }
}

Describe 'Test-Administrator' {
    It 'returns a boolean' {
        $result = Test-Administrator
        $result | Should -BeOfType [bool]
    }

    It 'returns false when not running as administrator' {
        # CI and normal user sessions are not elevated
        if (Test-Administrator) {
            Set-ItResult -Skipped -Because 'session is running as administrator'
        }
        Test-Administrator | Should -Be $false
    }
}
