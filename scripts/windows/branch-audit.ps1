<#
.SYNOPSIS
  Audit de ramas locales para saber si están integradas en develop/master.

.DESCRIPTION
  Ejecuta git fetch --all --prune y genera un CSV con:
  branch, upstream, merged_into_develop, merged_into_master,
  commits_not_in_develop, commits_not_in_master,
  last_commit_hash, last_commit_author, last_commit_date

.PARAMETER Develop
  Nombre de la rama de stage (por defecto 'develop').

.PARAMETER Master
  Nombre de la rama de producción (por defecto 'master').

.PARAMETER Output
  Ruta del CSV de salida (por defecto 'branch-audit.csv').

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\branch-audit.ps1 -Develop 'develop' -Master 'master' -Output 'audit.csv'
#>

param(
  [string]$Develop = 'develop',
  [string]$Master = 'master',
  [string]$Output = 'branch-audit.csv'
)

function Exec-Git {
  param($Args)
  $proc = & git $Args 2>$null
  return $proc
}

# Comprobar que estamos en un repositorio git
if (-not (Test-Path .git)) {
  Write-Error "No parece ser la raíz de un repositorio git. Ejecuta el script desde la raíz del repo."
  exit 1
}

Write-Host "Actualizando referencias remotas..."
& git fetch --all --prune

# Header CSV
$header = "branch,upstream,merged_into_develop,merged_into_master,commits_not_in_develop,commits_not_in_master,last_commit_hash,last_commit_author,last_commit_date"
Set-Content -Path $Output -Value $header -Encoding UTF8

# Obtener ramas locales
$branches = (& git for-each-ref --format='%(refname:short)' refs/heads/) | Where-Object { $_ -ne $null }

$total = 0
$candidates = @()

foreach ($b in $branches) {
  $total++
  if ($b -eq $Develop -or $b -eq $Master) {
    continue
  }

  # upstream (puede estar vacío)
  $upstream = (& git for-each-ref --format='%(upstream:short)' "refs/heads/$b") -join ''
  if ($upstream -eq '') { $upstream = '' }

  # commits exclusivos con develop
  try {
    $countsDevRaw = (& git rev-list --left-right --count "$Develop...$b")
    $countsDev = $countsDevRaw -split '\s+' | Where-Object { $_ -ne '' }
  } catch {
    $countsDev = @('0','0')
  }
  if ($countsDev.Length -lt 2) { $countsDev = @('0','0') }
  $commitsNotInDevelop = [int]$countsDev[1]

  # commits exclusivos con master
  try {
    $countsMasterRaw = (& git rev-list --left-right --count "$Master...$b")
    $countsMaster = $countsMasterRaw -split '\s+' | Where-Object { $_ -ne '' }
  } catch {
    $countsMaster = @('0','0')
  }
  if ($countsMaster.Length -lt 2) { $countsMaster = @('0','0') }
  $commitsNotInMaster = [int]$countsMaster[1]

  $mergedDev = if ($commitsNotInDevelop -eq 0) { 'yes' } else { 'no' }
  $mergedMaster = if ($commitsNotInMaster -eq 0) { 'yes' } else { 'no' }

  # último commit
  try {
    $lastRaw = (& git log -1 --format='%h;%an;%ai' $b)
    if (-not $lastRaw) { $lastRaw = ";;" }
  } catch {
    $lastRaw = ";;"
  }
  $parts = $lastRaw -split ';',3
  $lastHash = $parts[0].Trim()
  $lastAuthor = if ($parts.Length -ge 2) { $parts[1].Trim() } else { '' }
  $lastDate = if ($parts.Length -ge 3) { $parts[2].Trim() } else { '' }

  # Escapar dobles comillas si las hubiera
  $escape = { param($s) ($s -replace '"','""') }

  $line = '"{0}","{1}","{2}","{3}","{4}","{5}","{6}","{7}","{8}"' -f `
    (& $escape $b), (& $escape $upstream), $mergedDev, $mergedMaster, `
    $commitsNotInDevelop, $commitsNotInMaster, `
    (& $escape $lastHash), (& $escape $lastAuthor), (& $escape $lastDate)

  Add-Content -Path $Output -Value $line -Encoding UTF8

  if ($mergedDev -eq 'yes' -and $commitsNotInDevelop -eq 0) {
    $candidates += $b
  }
}

Write-Host "Reporte generado en: $Output"
Write-Host "Ramas escaneadas: $total"
if ($candidates.Count -gt 0) {
  Write-Host "Candidatas a borrar (mergeadas en $Develop):"
  $candidates | ForEach-Object { Write-Host " - $_" }
} else {
  Write-Host "No se detectaron ramas claramente candidatas a borrar (mergeadas en $Develop)."
}

Write-Host "`nSiguientes pasos recomendados:"
Write-Host "1) Abre el CSV y revisa las filas marcadas como merged_into_develop = yes."
Write-Host "2) Verifica que el PR asociado esté cerrado y que la CI pasó (si aplica)."
Write-Host "3) Haz backup remoto antes de borrar si lo consideras necesario:"
Write-Host "   git push origin refs/heads/<branch>:refs/heads/archive/<branch>"
Write-Host "4) Borrar localmente: git branch -d <branch>"
Write-Host "   Borrar remoto: git push origin --delete <branch>"
Write-Host "`nSi quieres, adapto esto para que consulte PRs abiertos y el estado de CI en GitHub/GitLab automáticamente."
