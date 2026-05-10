param([string]$InputJson)

$input = if ($InputJson) { $InputJson } else { $input | Out-String }
$data = $input | ConvertFrom-Json

$modelName   = $data.model.display_name
$currentDir  = $data.workspace.current_dir
$outputStyle = $data.output_style.name

$dirName = Split-Path $currentDir -Leaf

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    $gitCmd = Get-Command 'C:\Program Files\Git\cmd\git.exe' -ErrorAction SilentlyContinue
}

$gitInfo = ''
if ($gitCmd) {
    & $gitCmd.Source rev-parse --git-dir 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $branch = & $gitCmd.Source branch --show-current 2>$null
        if ($branch) {
            & $gitCmd.Source diff --quiet 2>$null; $unstaged = $LASTEXITCODE -ne 0
            & $gitCmd.Source diff --cached --quiet 2>$null; $staged = $LASTEXITCODE -ne 0
            $dirty = $unstaged -or $staged
            $gitInfo = if ($dirty) { "(git:$branch*)" } else { "(git:$branch)" }
        }
    }
}

$parts = @($dirName)
if ($gitInfo)  { $parts += $gitInfo }
$parts += "[$modelName]"
if ($outputStyle -and $outputStyle -ne 'default' -and $outputStyle -ne 'null') {
    $parts += "{$outputStyle}"
}

Write-Host ($parts -join ' ') -NoNewline
