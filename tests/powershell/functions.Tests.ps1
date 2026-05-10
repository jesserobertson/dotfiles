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
