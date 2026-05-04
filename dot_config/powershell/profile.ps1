Import-Module "$PSScriptRoot/functions.psm1"
Import-Module "$PSScriptRoot/gittools.psm1"

$global:profile_initialized = $false

# Use XDG base dirs so tools like Neovim find config in ~/.config rather than AppData
$DataHome = Set-EnvDefault XDG_DATA_HOME   @($HOME, ".local", "share")
Set-EnvDefault XDG_CONFIG_HOME @($HOME, ".config")
Set-EnvDefault XDG_STATE_HOME  @($HOME, ".local", "state")
Set-EnvDefault XDG_CACHE_HOME  @($HOME, ".cache")

# Add custom module path to avoid OneDrive Documents redirection
$ModuleHome = [IO.Path]::Combine($DataHome, "powershell", "modules")
if (-not ($env:PsModulePath -split [IO.Path]::PathSeparator -contains $ModuleHome))
{
    $env:PsModulePath = "$ModuleHome" + [IO.Path]::PathSeparator + $env:PsModulePath
}

# Add paths — first item in the list ends up first in PATH
$paths = @(
    [IO.Path]::Combine($DataHome, "powershell", "bin"),
    [IO.Path]::Combine($HOME, ".local", "bin"),
    [IO.Path]::Combine($HOME, "scoop", "shims"),
    [IO.Path]::Combine($HOME, ".pixi", "bin"),
    [IO.Path]::Combine($HOME, ".local", "share", "cargo", "bin")
)
[array]::Reverse($paths)
foreach ($p in $paths)
{
    Add-EnvPath $p
}

# Skip interactive profile for Claude Code / automated tools
if ($env:CLAUDECODE)
{
    # Allow Claude Code to use the PowerShell tool
    $env:CLAUDE_CODE_USER_POWERSHELL_TOOL = "1"
    return
}

$global:term_app = if ($env:WT_SESSION) { 'WindowsTerminal' }
                   elseif ($env:TERM_PROGRAM -eq 'vscode') { 'vscode' }
                   elseif ($env:WEZTERM_PANE) { 'WezTerm' }
                   else { $null }

$global:Prompts = @{
    Current = "Simple"
    Original = $Function:Prompt
    Simple = {
        "$([char]27)[36m$($MyInvocation.HistoryId)" +
        "$([char]27)[37m $pwd$([char]27)[0m`n$([char]0x276f) "
    }
    Starship = {}  # filled in below after starship init
    StarshipShort = {}  # filled in below after starship init
    OldPrompt = { . (Convert-Path "$DataHome/powershell/scripts/OldPrompt") }
}

$Interactive = "$DataHome/powershell/scripts/Init-Profile.ps1"
if ($Host.UI.RawUI.KeyAvailable)
{
    $Controlled = $false
    while ($Host.Ui.RawUI.KeyAvailable -and ($key = $Host.UI.RawUI.ReadKey("NoEcho,Intercept,IncludeKeyDown,IncludeKeyUp")))
    {
        if (!$Controlled -and $key.ControlKeyState -match "LeftCtrlPressed")
        {
            $Controlled = $true
        }
    }
    if ($controlled)
    {
        Write-Host "Skipping interactive config. To complete, run:`n. $Interactive"
        $function:prompt = $global:Prompts.Simple
        return
    }
}

# Only load interactive profile for interactive shells
if ([System.Environment]::UserInteractive)
{
    # Enable PSReadLine
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows

    # Load completions
    . "$PSScriptRoot/completions.ps1"

    # Start starship prompt
    if (get-command 'starship' -ErrorAction SilentlyContinue)
    {
        Invoke-Expression (&starship init powershell)
        $global:Prompts.Starship = $function:prompt
        $global:Prompts.StarshipShort = { &starship prompt --profile short }
        Switch-Prompt -prompt Starship
    } else
    {
        Write-Host "Preparing interactive session for first use..." -ForegroundColor Cyan
        Switch-Prompt -prompt "OldPrompt"
    }

    Get-MessageOfTheDay
}
