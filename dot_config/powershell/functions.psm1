
function Set-EnvDefault
{
    <#
    .SYNOPSIS
        Sets an environment variable to a default path if not already defined.
    .PARAMETER Name
        The environment variable name (e.g. 'XDG_DATA_HOME').
    .PARAMETER Default
        Path segments to join as the default value (e.g. @($HOME, '.local', 'share')).
    .EXAMPLE
        $DataHome = Set-EnvDefault XDG_DATA_HOME @($HOME, '.local', 'share')
    #>
    param([string]$Name, [string[]]$Default)
    if (-not (Get-Item "env:$Name" -ErrorAction SilentlyContinue))
    {
        Set-Item "env:$Name" ([IO.Path]::Combine($Default))
    }
    (Get-Item "env:$Name").Value
}

function Add-EnvPath
{
    <#
    .SYNOPSIS
        Prepends a directory to PATH if not already present.
    .PARAMETER Path
        The directory to add to the front of PATH.
    .EXAMPLE
        Add-EnvPath "$HOME\.local\bin"
    #>
    param([string]$Path)
    $current = $env:PATH -split ';'
    if (-not ($current | Where-Object { $_ -ieq $Path }))
    {
        $env:PATH = "$Path;" + $env:PATH
    }
}

function Test-Administrator
{
    <#
    .SYNOPSIS
        Returns true if the current session is running as Administrator.
    .EXAMPLE
        if (Test-Administrator) { Write-Host "Elevated" }
    #>
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $AdministratorRole = [Security.Principal.WindowsBuiltInRole] "Administrator"
    ([Security.Principal.WindowsPrincipal]$CurrentUser).IsInRole($AdministratorRole)
}

function Get-MessageOfTheDay
{
    <#
    .SYNOPSIS
        Displays a summary of system info, outdated scoop packages, and chezmoi status.
    .EXAMPLE
        Get-MessageOfTheDay
    #>
    $output = [System.Text.StringBuilder]::new()
    $dash = "." * $Host.UI.RawUI.WindowSize.Width

    [void]$output.AppendLine($dash)
    [void]$output.AppendLine("- Hostname: $(hostname)")
    [void]$output.AppendLine("- User: $(whoami)")
    [void]$output.AppendLine("- Date: $(Get-Date)")

    if (Get-Command scoop -ErrorAction SilentlyContinue)
    {
        $outdatedPackages = (scoop status 2>$null) -join "`n"
        if (-not [string]::IsNullOrEmpty($outdatedPackages))
        {
            [void]$output.AppendLine($dash)
            [void]$output.AppendLine("Scoop Packages To Update")
            [void]$output.AppendLine($outdatedPackages)
        }
    }

    if (Get-Command winget -ErrorAction SilentlyContinue)
    {
        $wingetUpdates = (winget upgrade 2>$null) | Where-Object { $_ -match '^\S' -and $_ -notmatch '^Name|^-|upgrades available\.|No installed' }
        if ($wingetUpdates)
        {
            [void]$output.AppendLine($dash)
            [void]$output.AppendLine("WinGet Packages To Update")
            [void]$output.AppendLine(($wingetUpdates -join "`n"))
        }
    }

    if (Get-Command chezmoi -ErrorAction SilentlyContinue)
    {
        $chezmoiStatus = (chezmoi status) -join "`n"
        if (-not [string]::IsNullOrEmpty($chezmoiStatus))
        {
            [void]$output.AppendLine($dash)
            [void]$output.AppendLine("Chezmoi Status")
            [void]$output.AppendLine($chezmoiStatus)
        }
    }
    [void]$output.Append($dash)
    Write-Host $output -NoNewline
}

function Set-LocationButBetter
{
    <#
    .SYNOPSIS
        Enhanced cd that uses Push-Location, handles dotdot depth (e.g. '....'), navigates to file's parent, and integrates with zoxide.
    .PARAMETER Path
        Destination path, a dotdot string (e.g. '....'), or '-' to go back.
    .EXAMPLE
        cd ~/Projects
        cd ....          # go up 3 levels
        cd -             # go back
    #>
    param (
        [Parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        $Path
    )

    process
    {
        if ($MyInvocation.BoundParameters.Count -eq 0)
        {
            $Path = $HOME
        }
        # N dots = N-1 levels up: '..' = 1, '...' = 2, '....' = 3, etc.
        if ($Path -match '^\.{2,}$')
        {
            $depth = $Path.Length
            $path = Get-Location
            for ($i = 1; $i -lt $depth; $i++)
            {
                $path = (Split-Path $path -Parent)
            }
            Push-Location $path
        } elseif ($Path -eq '-')
        {
            Pop-Location
        } else
        {
            $resolvedPath = Resolve-Path $Path -ErrorAction SilentlyContinue
            if ($null -eq $resolvedPath)
            {
                Write-Error "Cannot find path '$Path' because it does not exist."
                return
            }
            if ([System.IO.File]::Exists($resolvedPath.Path))
            {
                Push-Location (Split-Path $resolvedPath.Path -Parent)
            } else
            {
                Push-Location $resolvedPath.Path
            }
        }
        # Feed the new location to zoxide's database
        if ($global:__zoxide_initialized)
        {
            $cwd = (Get-Location).ProviderPath
            if ($null -ne $cwd)
            {
                zoxide add -- $cwd
            }
        }
    }
}

Set-Alias -Name cd -Value Set-LocationButBetter -Option AllScope -Scope Global -Force
Set-Alias -Name .. -Value Set-LocationButBetter
Set-Alias -Name ... -Value Set-LocationButBetter

# Zoxide integration — check once per session, integrate with Push-Location stack
if (-not $global:__zoxide_initialized -and (Get-Command zoxide -ErrorAction SilentlyContinue))
{
    $global:__zoxide_initialized = $true
    zoxide init powershell --no-cmd --hook none | Out-String | Invoke-Expression
    # Override __zoxide_cd to use Push-Location and feed zoxide's database
    function global:__zoxide_cd($dir, $literal)
    {
        if ($dir -eq '-')
        {
            Pop-Location
        } elseif ($literal)
        {
            Push-Location -LiteralPath $dir -ErrorAction Stop
        } else
        {
            Push-Location -Path $dir -ErrorAction Stop
        }
        $cwd = (Get-Location).ProviderPath
        if ($null -ne $cwd)
        {
            zoxide add -- $cwd
        }
    }
    Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
    Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force
}

function Switch-Prompt
{
    <#
    .SYNOPSIS
        Cycles through or sets the active prompt theme.
    .PARAMETER Prompt
        Name of the prompt to switch to. Omit to cycle to the next one.
    .PARAMETER NoShellIntegration
        Skip re-applying terminal shell integration after switching.
    .EXAMPLE
        Switch-Prompt
        Switch-Prompt Starship
    #>
    param(
        [Parameter(Position = 0)]
        [ValidateSet('Simple', 'Starship', 'Original', 'OldPrompt')]
        [string]$Prompt,
        [switch]
        $NoShellIntegration
    )
    $current = $global:Prompts.Current
    if ([string]::IsNullOrEmpty($Prompt))
    {
        [array]$keys = $global:Prompts.Keys | Where-Object { $_ -ne 'Current' }
        try
        {
            $currentIndex = $keys.IndexOf($current)
        } catch
        {
            Write-Debug "Current prompt '$($current)' not found in keys. Defaulting to 'Simple'."
            $currentIndex = 0
        }
        Write-Debug "Current Prompt: $($current) at index $currentIndex"
        $next = $currentIndex + 1
        if ($next -ge $keys.Count)
        {
            Write-Debug "Wrapping around to the first prompt"
            $next = 0
        }
        $Prompt = $keys[$next]
    }
    Write-Host "Switching prompt from '$($current)' to '$Prompt'"
    $global:Prompts.Current = $Prompt
    $function:prompt = $global:Prompts.$Prompt
    if (-not $NoShellIntegration)
    {
        Set-ShellIntegration -TerminalProgram $global:term_app -NoOriginalReset
    }
}

# Reference:
# https://devblogs.microsoft.com/commandline/shell-integration-in-the-windows-terminal/
# Forked from https://gist.github.com/mdgrs-mei/1599cb07ef5bc67125ebffba9c8f1e37
function Set-ShellIntegration
{
    param
    (
        [ValidateSet('WindowsTerminal', 'ITerm2', 'WezTerm', 'vscode')]
        [String]$TerminalProgram = $global:term_app,
        [switch]$NoOriginalReset
    )

    Write-Host "Setting up shell integration..."
    # Restore hooked functions in case this script is executed accidentally twice
    if ($global:shellIntegrationGlobals -and -not $NoOriginalReset)
    {
        $function:global:PSConsoleHostReadLine = $global:shellIntegrationGlobals.originalPSConsoleHostReadLine
        $function:global:Prompt = $global:shellIntegrationGlobals.originalPrompt
    }

    $global:shellIntegrationGlobals = @{
        terminalProgram = $TerminalProgram
        originalPSConsoleHostReadLine = $function:global:PSConsoleHostReadLine
        originalPrompt = $function:global:Prompt
        lastCommand = $null

        getExitCode = {
            param ($lastCommandStatus)
            if ($lastCommandStatus -eq $true)
            {
                return 0
            }

            if ($Error[0])
            {
                $lastHistory = Get-History -Count 1
                $isPowerShellError = $Error[0].InvocationInfo.HistoryId -eq $lastHistory.Id
            }

            if ($isPowerShellError)
            {
                return 1
            } else
            {
                return $LastExitCode
            }
        }
    }

    $function:global:PSConsoleHostReadLine = {
        $commandExecuted = "$([char]27)]133;C$([char]7)"
        $command = $global:shellIntegrationGlobals.originalPSConsoleHostReadLine.Invoke()

        $commandExecuted | Write-Host -NoNewline
        $command

        $global:shellIntegrationGlobals.lastCommand = $command
    }

    $function:global:Prompt = {
        $lastCommandStatus = $?

        if ($global:shellIntegrationGlobals.lastCommand)
        {
            $exitCode = $global:shellIntegrationGlobals.getExitCode.Invoke($lastCommandStatus)
            $commandFinished = "$([char]27)]133;D;$exitCode$([char]7)"
        } else
        {
            $commandFinished = "$([char]27)]133;D$([char]7)"
        }

        $currentLocation = $ExecutionContext.SessionState.Path.CurrentLocation
        switch ($global:shellIntegrationGlobals.terminalProgram)
        {
            'WindowsTerminal'
            {
                $setWorkingDirectory = "$([char]27)]9;9;`"$currentLocation`"$([char]7)"
            }
            'ITerm2'
            {
                $setWorkingDirectory = "$([char]27)]1337;CurrentDir=$currentLocation$([char]7)"
            }
            'WezTerm'
            {
                $provider_path = $currentLocation.ProviderPath -replace "\\", "/"
                $setWorkingDirectory = "$([char]27)]7;file://${env:COMPUTERNAME}/${provider_path}$([char]27)\"
            }
        }

        $promptStarted = "$([char]27)]133;A$([char]7)"
        $commandStarted = "$([char]27)]133;B$([char]7)"
        $prompt = $global:shellIntegrationGlobals.originalPrompt.Invoke()

        $commandFinished + $promptStarted + $setWorkingDirectory + $prompt + $commandStarted
    }
}

Export-ModuleMember -Function Add-EnvPath, Set-EnvDefault, Get-MessageOfTheDay, Test-Administrator, Set-LocationButBetter, Switch-Prompt, Set-ShellIntegration
Export-ModuleMember -Alias cd, .., ...
