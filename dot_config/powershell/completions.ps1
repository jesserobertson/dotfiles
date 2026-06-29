function Import-Completion
{
    <#
    .SYNOPSIS
        Loads shell completions for a command if it exists on PATH.
        Completions are cached per tool version in XDG_CACHE_HOME and only
        regenerated when the tool is upgraded.
    .PARAMETER Command
        The command name to check for (e.g. 'gh').
    .PARAMETER Script
        Scriptblock that generates completion script text for the current shell.
    .EXAMPLE
        Import-Completion gh { gh completion -s powershell }
    #>
    param([string]$Command, [scriptblock]$Script)
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) { return }

    $cacheHome = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { [IO.Path]::Combine($HOME, '.cache') }
    $cacheDir  = [IO.Path]::Combine($cacheHome, 'powershell', 'completions')

    # Use the binary's last-write time as cache key — no process spawn needed
    $mtime     = (Get-Item $cmd.Source -ErrorAction SilentlyContinue)?.LastWriteTimeUtc.Ticks
    $cacheFile = if ($mtime) { [IO.Path]::Combine($cacheDir, "${Command}_${mtime}.ps1") } else { $null }

    if ($cacheFile -and (Test-Path $cacheFile))
    {
        . $cacheFile
        return
    }

    $content = (& $Script) | Out-String

    if ($cacheFile)
    {
        if (-not (Test-Path $cacheDir)) { [void](New-Item -ItemType Directory -Path $cacheDir -Force) }
        Get-ChildItem $cacheDir -Filter "${Command}_*.ps1" | Remove-Item -Force
        Set-Content -Path $cacheFile -Value $content
    }

    Invoke-Expression $content
}

# Load completions for installed tools
# Note Zoxide handled by the new functions in functinos.psm1
Import-Completion chezmoi { chezmoi completion powershell }
Import-Completion gh      { gh completion -s powershell }
Import-Completion zoxide  { zoxide init powershell }
Import-Completion rip     { rip completions powershell }
Import-Completion rg      { rg --generate complete-powershell }
Import-Completion fd      { fd --gen-completions powershell }
