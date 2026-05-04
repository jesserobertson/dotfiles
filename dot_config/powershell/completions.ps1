function Import-Completion
{
    <#
    .SYNOPSIS
        Loads shell completions for a command if it exists on PATH.
    .PARAMETER Command
        The command name to check for (e.g. 'gh').
    .PARAMETER Script
        Scriptblock that generates completion script text for the current shell.
    .EXAMPLE
        Import-Completion gh { gh completion -s powershell }
    #>
    param([string]$Command, [scriptblock]$Script)
    if (Get-Command $Command -ErrorAction SilentlyContinue)
    {
        & $Script | Out-String | Invoke-Expression
    }
}

# Load completions for installed tools
# Note Zoxide handled by the new functions in functinos.psm1
Import-Completion chezmoi { chezmoi completion powershell }
Import-Completion gh      { gh completion -s powershell }
