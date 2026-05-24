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
    $wingetOut = winget upgrade 2>$null
    $header    = $wingetOut | Where-Object { $_ -match '\bAvailable\b' } | Select-Object -First 1
    if ($header)
    {
        $idIdx      = [regex]::Match($header, '\bId\b').Index
        $versionIdx = [regex]::Match($header, '\bVersion\b').Index
        $availIdx   = [regex]::Match($header, '\bAvailable\b').Index
        $sourceIdx  = [regex]::Match($header, '\bSource\b').Index
        $wingetUpdates = $wingetOut |
            Where-Object { $_ -match 'winget\s*$' -and $_.Length -gt $sourceIdx } |
            ForEach-Object {
                $name      = $_.Substring(0, $idIdx).Trim()
                $version   = $_.Substring($versionIdx, $availIdx - $versionIdx).Trim()
                $available = $_.Substring($availIdx, $sourceIdx - $availIdx).Trim()
                if ($name -and $available) { "  ${name}: $version -> $available" }
            }
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
