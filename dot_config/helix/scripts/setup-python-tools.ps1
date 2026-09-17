
$ErrorActionPreference = "Stop"

Write-Host "Installing Helix Python tooling..."

if (Get-Command pixi -ErrorAction SilentlyContinue) {

    pixi global install ruff
    pixi global install basedpyright

} else {

    Write-Warning "pixi not found; falling back to pipx"

    if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
        throw "Neither pixi nor pipx found"
    }

    pipx install ruff --force
    pipx install basedpyright --force
}

Write-Host "Verifying..."

Get-Command ruff -ErrorAction Stop | Out-Null
Get-Command basedpyright-langserver -ErrorAction Stop | Out-Null

Write-Host "Python tooling installed"
