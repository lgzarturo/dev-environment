<#
.SYNOPSIS
    Script para auditar y limpiar ramas fusionadas en un repositorio Git.
.DESCRIPTION
    Este script revisa las ramas remotas en un repositorio Git,
    identifica cuáles han sido fusionadas en la rama base (por defecto 'develop'),
    y genera un reporte en CSV. Opcionalmente, puede crear un script para eliminar
    las ramas fusionadas del repositorio remoto.
#>

param(
    [string]$RepoPath = ".",
    [string]$BaseBranch = "develop",
    [switch]$DryRun
)

# Cambiar al directorio del repositorio
Set-Location $RepoPath

# Obtener últimas referencias
Write-Host "Actualizando referencias remotas..." -ForegroundColor Yellow
git fetch --all --prune

# Lista de ramas remotas excluyendo las principales
$branches = git branch -r `
    | Where-Object {$_ -notmatch "origin/$BaseBranch"} `
    | Where-Object {$_ -notmatch "origin/main"} `
    | Where-Object {$_ -notmatch "origin/master"} `
    | ForEach-Object { $_.Trim() }

# Inicializar reporte
$report = @()

foreach ($branch in $branches) {
    $branchName = $branch -replace "origin/", ""
    Write-Host "Revisando $branchName..." -ForegroundColor Cyan

    # Verificar si ya está contenido en develop
    $isMerged = git branch --remotes --merged $BaseBranch `
        | Select-String $branchName

    if ($isMerged) {
        $status = "MERGED"
    } else {
        $status = "NOT MERGED"
    }

    $report += [PSCustomObject]@{
        Branch   = $branchName
        Status   = $status
    }
}

# Guardar reporte en CSV
$reportPath = Join-Path $RepoPath "branch_audit_report.csv"
$report | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8

Write-Host "Reporte generado en: $reportPath" -ForegroundColor Green

if ($DryRun) {
    Write-Host "Modo Dry-Run: Generando script de eliminación..." -ForegroundColor Yellow
    $deleteScript = Join-Path $RepoPath "delete_merged_branches.ps1"

    $report | Where-Object { $_.Status -eq "MERGED" } | ForEach-Object {
        "git push origin --delete $($_.Branch)" | Out-File -FilePath $deleteScript -Append -Encoding UTF8
    }

    Write-Host "Script para eliminar ramas creado en: $deleteScript" -ForegroundColor Green
}
