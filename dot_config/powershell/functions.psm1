
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
        Displays system info plus once-per-day update summaries (scoop/winget/chezmoi).
        On a cache hit the full output is immediate. On a cache miss the header prints
        instantly and the slow checks run in a background job; the results are flushed
        above the next prompt via Set-ShellIntegration. Use -Force to refresh mid-day.
    .PARAMETER Force
        Bypass the cache, run synchronously, and show output immediately.
    .EXAMPLE
        Get-MessageOfTheDay
        Get-MessageOfTheDay -Force
    #>
    param([switch]$Force)

    $stateHome = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME } else { [IO.Path]::Combine($HOME, '.local', 'state') }
    $stateDir  = [IO.Path]::Combine($stateHome, 'powershell')
    $today     = Get-Date -Format 'yyyy-MM-dd'
    $cacheFile = [IO.Path]::Combine($stateDir, "motd_$today.txt")
    $dash = '.' * $Host.UI.RawUI.WindowSize.Width

    if (-not $Force -and (Test-Path $cacheFile))
    {
        if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch } else { Write-Host "$dash`n- Hostname: $env:COMPUTERNAME`n- User: $env:USERDOMAIN\$env:USERNAME`n- Date: $(Get-Date)`n" -NoNewline }
        Write-Host (Get-Content $cacheFile -Raw) -NoNewline
        return
    }

    # Cache miss: print header immediately, run slow checks in background
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch } else { Write-Host "$dash`n- Hostname: $env:COMPUTERNAME`n- User: $env:USERDOMAIN\$env:USERNAME`n- Date: $(Get-Date)`n" -NoNewline }

    if ($global:motdJob)
    {
        $global:motdJob | Stop-Job -ErrorAction SilentlyContinue
        $global:motdJob | Remove-Job -Force -ErrorAction SilentlyContinue
        $global:motdJob = $null
    }

    $motdScript    = [IO.Path]::Combine($PSScriptRoot, 'motd-update.ps1')
    $global:motdJob = Start-ThreadJob -FilePath $motdScript -ArgumentList $dash, $cacheFile, $stateDir

    if ($Force)
    {
        # Force: block until done and display immediately
        $completedJob = $global:motdJob | Wait-Job
        if ($completedJob.State -eq 'Failed')
        {
            Write-Warning "MOTD update failed: $($completedJob.ChildJobs[0].JobStateInfo.Reason.Message)"
        }
        $body = $completedJob | Receive-Job
        $global:motdJob | Remove-Job -Force -ErrorAction SilentlyContinue
        $global:motdJob = $null
        if ($body) { Write-Host $body -NoNewline }
    }
    # else: Set-ShellIntegration's Prompt hook flushes the job above the next prompt
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
                # Override caller's $ErrorActionPreference so Write-Error remains non-terminating
                # even when called from a Pester test (which sets $ErrorActionPreference='Stop').
                $local:ErrorActionPreference = 'Continue'
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
        [ValidateSet('Simple', 'Starship', 'StarshipShort', 'Original', 'OldPrompt')]
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
        [ValidateSet('', 'WindowsTerminal', 'ITerm2', 'WezTerm', 'vscode')]
        [String]$TerminalProgram = $global:term_app,
        [switch]$NoOriginalReset
    )

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

        # Flush async MOTD output above the prompt once the background job finishes
        if ($global:motdJob -and $global:motdJob.State -in 'Completed', 'Failed')
        {
            $body = Receive-Job $global:motdJob -ErrorAction SilentlyContinue
            if ($body) { Write-Host $body }
            Remove-Job $global:motdJob -Force -ErrorAction SilentlyContinue
            $global:motdJob = $null
        }

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

function Measure-StartupTime
{
    <#
    .SYNOPSIS
        Times each step of the interactive profile to identify slow components.
        Note: module timings reflect re-import cost; open a fresh terminal for cold-load numbers.
    .EXAMPLE
        Measure-StartupTime
    #>
    $psdir = Split-Path $PROFILE.CurrentUserCurrentHost

    function tw($label, $block)
    {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        & $block
        $sw.Stop()
        [pscustomobject]@{ Step = $label; Ms = $sw.ElapsedMilliseconds }
    }

    $results = @(
        (tw 'Import functions.psm1'  { Import-Module "$psdir/functions.psm1" -Force -ErrorAction SilentlyContinue })
        (tw 'Import gittools.psm1'   { Import-Module "$psdir/gittools.psm1"  -Force -ErrorAction SilentlyContinue })
        (tw 'Import PSReadLine'      { Import-Module PSReadLine -ErrorAction SilentlyContinue })
        (tw 'chezmoi completion'     { if (gcm chezmoi -ea 0) { chezmoi completion powershell | Out-Null } })
        (tw 'gh completion'          { if (gcm gh -ea 0)      { gh completion -s powershell   | Out-Null } })
        (tw 'starship init'          { if (gcm starship -ea 0) { & starship init powershell   | Out-Null } })
        (tw 'scoop status'           { if (gcm scoop -ea 0)   { scoop status 2>$null          | Out-Null } })
        (tw 'winget upgrade'         { if (gcm winget -ea 0)  { winget upgrade 2>$null        | Out-Null } })
        (tw 'chezmoi status'         { if (gcm chezmoi -ea 0) { chezmoi status                | Out-Null } })
    )

    $results | Sort-Object Ms -Descending | Format-Table -AutoSize
    "Total: $(($results | Measure-Object Ms -Sum).Sum) ms"
}

Export-ModuleMember -Function Add-EnvPath, Set-EnvDefault, Get-MessageOfTheDay, Test-Administrator, Set-LocationButBetter, Switch-Prompt, Set-ShellIntegration, Measure-StartupTime
Export-ModuleMember -Alias cd, .., ...
