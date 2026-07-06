Import-Module "$PSScriptRoot/functions.psm1"
Import-Module "$PSScriptRoot/gittools.psm1"

# Use XDG base dirs so tools like Neovim find config in ~/.config rather than AppData
$DataHome = Set-EnvDefault XDG_DATA_HOME   @($HOME, ".local", "share")
[void](Set-EnvDefault XDG_CONFIG_HOME @($HOME, ".config"))
[void](Set-EnvDefault XDG_STATE_HOME  @($HOME, ".local", "state"))
[void](Set-EnvDefault XDG_CACHE_HOME  @($HOME, ".cache"))
[void](Set-EnvDefault SCOOP           @($HOME, ".local", "scoop"))

# Set Zed as default editor
# Set-Item "env:EDITOR" "zed --wait"
# Set-Item "env:VISUAL" "zed --wait"

# Set helix as default editor
Set-Item "env:EDITOR" hx
Set-Item "env:VISUAL" hx

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
    [IO.Path]::Combine($HOME, ".local", "scoop", "shims"),
    [IO.Path]::Combine($HOME, ".pixi", "bin"),
    [IO.Path]::Combine($HOME, ".local", "share", "cargo", "bin"),
    [IO.Path]::Combine($env:LOCALAPPDATA, "Microsoft", "WinGet", "Links"),
    # Git for Windows — winget installs here but doesn't always create a WinGet shim
    "C:\Program Files\Git\cmd"
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

# Only load interactive profile for interactive shells
if ([System.Environment]::UserInteractive)
{
    # Enable PSReadLine
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle InlineView
    Set-PSReadLineOption -EditMode Windows

    # Load completions
    . "$PSScriptRoot/completions.ps1"

    # Start starship prompt (init output cached by binary mtime — only reruns after upgrades)
    $starshipCmd = Get-Command 'starship' -ErrorAction SilentlyContinue
    if ($starshipCmd)
    {
        $starshipMtime = (Get-Item $starshipCmd.Source).LastWriteTimeUtc.Ticks
        $starshipCache = [IO.Path]::Combine($env:XDG_CACHE_HOME, 'powershell', "starship_init_$starshipMtime.ps1")
        if (-not (Test-Path $starshipCache))
        {
            $initScript = & starship init powershell
            $cacheDir = Split-Path $starshipCache
            if (-not (Test-Path $cacheDir)) { [void](New-Item -ItemType Directory -Path $cacheDir -Force) }
            Get-ChildItem $cacheDir -Filter 'starship_init_*.ps1' | Remove-Item -Force
            Set-Content -Path $starshipCache -Value $initScript
        }
        . $starshipCache
        $global:Prompts.Starship = $function:prompt
        $global:Prompts.StarshipShort = { &starship prompt --profile short }
        Switch-Prompt -prompt Starship
    } else
    {
        Write-Host "Preparing interactive session for first use..." -ForegroundColor Cyan
        Switch-Prompt -prompt "OldPrompt"
    }

#    Get-MessageOfTheDay
}
