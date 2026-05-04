param(
    [string]$Dash,
    [string]$CacheFile,
    [string]$StateDir
)

$sb = [System.Text.StringBuilder]::new()

if (Get-Command scoop -ErrorAction SilentlyContinue)
{
    $outdated = scoop status 2>$null | Where-Object { $_.Name }
    if ($outdated)
    {
        [void]$sb.AppendLine($Dash)
        [void]$sb.AppendLine('Scoop updates (run: scoop update *)')
        [void]$sb.AppendLine(($outdated | ForEach-Object {
            "  $($_.Name): $($_.'Installed Version') -> $($_.'Latest Version')"
        }) -join "`n")
    }
}

if (Get-Command winget -ErrorAction SilentlyContinue)
{
    $wingetUpdates = winget upgrade 2>$null |
        Where-Object { $_ -match '\s+winget\s*$' } |
        ForEach-Object {
            $parts = $_ -split '\s{2,}'
            if ($parts.Count -ge 4) { "  $($parts[0].Trim()): $($parts[2].Trim()) -> $($parts[3].Trim())" }
        }
    if ($wingetUpdates)
    {
        [void]$sb.AppendLine($Dash)
        [void]$sb.AppendLine('WinGet updates (run: winget upgrade --all)')
        [void]$sb.AppendLine(($wingetUpdates -join "`n"))
    }
}

if (Get-Command chezmoi -ErrorAction SilentlyContinue)
{
    $chezmoiStatus = (chezmoi status) -join "`n"
    if (-not [string]::IsNullOrEmpty($chezmoiStatus))
    {
        [void]$sb.AppendLine($Dash)
        [void]$sb.AppendLine('Chezmoi Status')
        [void]$sb.AppendLine($chezmoiStatus)
    }
}
[void]$sb.Append($Dash)

$body = $sb.ToString()

if (-not (Test-Path $StateDir))
{
    [void](New-Item -ItemType Directory -Path $StateDir -Force)
}
Get-ChildItem $StateDir -Filter 'motd_*.txt' | Remove-Item -Force
Set-Content -Path $CacheFile -Value $body

$body
