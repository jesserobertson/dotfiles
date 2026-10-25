<#
.SYNOPSIS
    Rename a project directory (and every Claude Code worktree under it) without
    losing its Claude Code conversations.

.DESCRIPTION
    PowerShell take on https://github.com/captivus/claude-mv that also covers
    nested directories such as .claude\worktrees\<slug>.

    Claude Code keeps history per working directory in
    ~\.claude\projects\<encoded-path>, where the encoded path is the directory
    path with every non-alphanumeric character replaced by '-'. Renaming a
    directory on disk therefore orphans its conversations. This script:

      1. Finds every ~\.claude\projects folder for the old root, its worktrees
         and any other nested directory, confirming each one by the "cwd" recorded
         in its sessions (so a sibling such as C:\Developer\goethite-old is left
         alone).
      2. Renames the directory on disk and runs `git worktree repair` so linked
         worktrees still find the main repository.
      3. Renames each project folder and rewrites the "cwd" of every session line,
         preserving file timestamps so the session list keeps its order.
      4. Rewrites the old path in ~\.claude.json, ~\.claude\history.jsonl and
         ~\.claude\settings.json (backups are kept next to each).

    Nothing is touched until preflight passes. Use -DryRun to see the plan.

.PARAMETER OldPath
    Directory to rename.

.PARAMETER NewName
    New leaf name (the directory stays in the same parent).

.PARAMETER DryRun
    Print what would happen and change nothing.

.PARAMETER Yes
    Skip the "Claude sessions are running" confirmation.

.EXAMPLE
    # From a plain PowerShell window, with all Claude sessions closed:
    .\rename-claude-project.ps1 -DryRun
    .\rename-claude-project.ps1
#>
[CmdletBinding()]
param(
    [string]$OldPath = 'C:\Developer\goethite',
    [string]$NewName = 'nimbus',
    [switch]$DryRun,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Get-EncodedPath([string]$Path) {
    [regex]::Replace($Path, '[^A-Za-z0-9]', '-')
}

# Regex matching the old root in any spelling Claude writes (C:\x, C:\\x as JSON
# escapes, C:/x, /c/x), capturing everything before the leaf as group 1.
function New-RootPattern([string]$Path) {
    $drive = $Path.Substring(0, 1)
    $parts = $Path.Substring(3).Split('\', [StringSplitOptions]::RemoveEmptyEntries)
    $leaf = $parts[-1]
    $parents = if ($parts.Count -gt 1) { $parts[0..($parts.Count - 2)] } else { @() }
    $sep = '(?:\\{1,2}|/)'
    $prefix = "(?:$drive`:|/$drive)$sep"
    foreach ($segment in $parents) { $prefix += [regex]::Escape($segment) + $sep }
    "(?i)($prefix)$([regex]::Escape($leaf))(?![A-Za-z0-9_-])"
}

# Rewrite a text file in place (streaming, backup kept), preserving its mtime.
# $LineFilter limits which lines are rewritten; the callback maps line -> line.
function Update-TextFile([string]$File, [scriptblock]$Rewrite, [string]$Needle, [switch]$Backup) {
    $info = Get-Item -LiteralPath $File
    $temp = "$File.rename-tmp"
    $changed = 0
    $reader = [System.IO.StreamReader]::new($File, $utf8)
    $writer = [System.IO.StreamWriter]::new($temp, $false, $utf8)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $new = & $Rewrite $line
                if ($new -ne $line) { $changed++; $line = $new }
            }
            $writer.Write($line); $writer.Write("`n")
        }
    } finally { $reader.Dispose(); $writer.Dispose() }
    if ($changed -eq 0) { Remove-Item -LiteralPath $temp; return 0 }
    if ($Backup) { Copy-Item -LiteralPath $File -Destination "$File.pre-rename.bak" -Force }
    $times = $info.LastWriteTimeUtc
    Move-Item -LiteralPath $temp -Destination $File -Force
    (Get-Item -LiteralPath $File).LastWriteTimeUtc = $times
    return $changed
}

# ---- Preflight ----------------------------------------------------------------

$oldRoot = (Resolve-Path -LiteralPath $OldPath).Path.TrimEnd('\')
$parent = Split-Path $oldRoot -Parent
$newRoot = Join-Path $parent $NewName
$leaf = Split-Path $oldRoot -Leaf
if (Test-Path -LiteralPath $newRoot) { throw "Target already exists: $newRoot" }

$claudeDir = Join-Path $HOME '.claude'
$projects = Join-Path $claudeDir 'projects'
$oldPrefix = Get-EncodedPath $oldRoot
$newPrefix = Get-EncodedPath $newRoot
$pattern = New-RootPattern $oldRoot
$swap = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $m.Groups[1].Value + $NewName }

# Project folders for the root and everything nested under it, confirmed by cwd.
$plan = @()
foreach ($dir in Get-ChildItem -LiteralPath $projects -Directory) {
    if ($dir.Name -ne $oldPrefix -and -not $dir.Name.StartsWith("$oldPrefix-")) { continue }
    $cwd = $null
    foreach ($session in Get-ChildItem -LiteralPath $dir.FullName -Filter *.jsonl -File | Select-Object -First 5) {
        foreach ($line in Get-Content -LiteralPath $session.FullName -TotalCount 60) {
            if ($line -match '"cwd":"((?:[^"\\]|\\.)*)"') { $cwd = ('"' + $Matches[1] + '"') | ConvertFrom-Json; break }
        }
        if ($cwd) { break }
    }
    if ($cwd) {
        $normal = $cwd -replace '^/([a-z])/', '${1}:\' -replace '/', '\'
        $inside = $normal.TrimEnd('\') -ieq $oldRoot -or $normal.StartsWith("$oldRoot\", [StringComparison]::OrdinalIgnoreCase)
        if (-not $inside) { Write-Host "skip  $($dir.Name) (cwd $cwd is outside $oldRoot)" -ForegroundColor Yellow; continue }
    } else {
        Write-Host "note  $($dir.Name) has no session cwd to verify; including it by name" -ForegroundColor Yellow
    }
    $newProject = $newPrefix + $dir.Name.Substring($oldPrefix.Length)
    if ($newProject.Length -gt 200) { Write-Warning "$newProject exceeds 200 chars; Claude hashes long names, so this folder may not be found." }
    if (Test-Path -LiteralPath (Join-Path $projects $newProject)) { throw "Project folder already exists: $newProject" }
    $plan += [pscustomobject]@{ Old = $dir.Name; New = $newProject; Path = $dir.FullName }
}

$worktrees = @(Get-ChildItem -LiteralPath (Join-Path $oldRoot '.claude\worktrees') -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') })

Write-Host "`nRename   $oldRoot  ->  $newRoot"
Write-Host "Projects $($plan.Count) conversation folder(s) to move"
$plan | ForEach-Object { Write-Host "         $($_.Old) -> $($_.New)" }
Write-Host "Worktrees $($worktrees.Count) to repair with git"

if ($DryRun) { Write-Host "`nDry run: nothing changed."; return }

$running = @(Get-Process -Name claude -ErrorAction SilentlyContinue)
if ($running -and -not $Yes) {
    Write-Warning "$($running.Count) claude process(es) are running. They hold $oldRoot open and rewrite ~\.claude.json."
    if ((Read-Host 'Close them first. Continue anyway? (y/N)') -notmatch '^[yY]') { return }
}

# ---- Rename the directory and repair git ---------------------------------------

Set-Location $parent
try { Move-Item -LiteralPath $oldRoot -Destination $newRoot }
catch { throw "Could not rename $oldRoot (a terminal, editor, rust-analyzer or cargo may hold it open). Nothing else was changed. $_" }
Write-Host "renamed directory"

if ($worktrees) {
    $repaired = $worktrees | ForEach-Object { Join-Path $newRoot ".claude\worktrees\$($_.Name)" }
    git -C $newRoot worktree repair @repaired
    Write-Host "repaired $($worktrees.Count) worktree(s)"
}

# ---- Move conversations --------------------------------------------------------

foreach ($item in $plan) {
    $target = Join-Path $projects $item.New
    Move-Item -LiteralPath $item.Path -Destination $target
    $rewritten = 0
    foreach ($file in Get-ChildItem -LiteralPath $target -Filter *.jsonl -File -Recurse) {
        $rewritten += Update-TextFile $file.FullName -Needle $leaf -Rewrite {
            param($line)
            [regex]::Replace($line, '("cwd":")((?:[^"\\]|\\.)*)(")', {
                param($m) $m.Groups[1].Value + [regex]::Replace($m.Groups[2].Value, $pattern, $swap) + $m.Groups[3].Value
            })
        }
    }
    Write-Host "moved $($item.Old) ($rewritten cwd line(s) rewritten)"
}

# ---- Global files that name the path -------------------------------------------

$globalFiles = @(
    @{ File = Join-Path $HOME '.claude.json';            Label = '~\.claude.json' }
    @{ File = Join-Path $claudeDir 'history.jsonl';       Label = 'history.jsonl' }
    @{ File = Join-Path $claudeDir 'settings.json';       Label = 'settings.json' }
)
foreach ($entry in $globalFiles) {
    if (-not (Test-Path -LiteralPath $entry.File)) { continue }
    $count = Update-TextFile $entry.File -Needle $leaf -Backup -Rewrite {
        param($line) [regex]::Replace($line, $pattern, $swap)
    }
    Write-Host "patched $($entry.Label) ($count line(s))"
}

Write-Host "`nDone. Open Claude Code in $newRoot and run /resume to confirm the history is there."
Write-Host "Not handled: build caches (target\, Python virtualenvs) hold absolute paths and rebuild on demand;"
Write-Host "prose in settings.json and memory files that says 'goethite' is left for you to edit."
