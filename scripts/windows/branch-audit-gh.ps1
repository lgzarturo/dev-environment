<#
.SYNOPSIS
  Auditoría de ramas + comprobación de PRs y estado de CI en GitHub. Produce CSV y script de borrado en modo dry-run.

.DESCRIPTION
  Requiere:
    - PowerShell (Windows 11)
    - Git disponible en PATH
    - Variable de entorno GITHUB_TOKEN con un token que tenga permisos repo (lectura de PRs, commits, statuses)
  Opciones:
    - Usa la API de GitHub (intenta inferir owner/repo desde remote 'origin').
    - No borra nada automáticamente. Genera un script de borrado comentado para aprobación.

.PARAMETER Develop
  Nombre de la rama de stage. Default: develop

.PARAMETER Master
  Nombre de la rama de producción. Default: master

.PARAMETER Output
  CSV de salida. Default: branch-pr-audit.csv

.PARAMETER DeleteScript
  Script de borrado dry-run a generar. Default: delete-branches.ps1

.PARAMETER Remote
  Remote a inspeccionar (para remote upstream). Default: origin

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\branch-audit-gh.ps1 -Develop 'develop' -Master 'master' -Output 'audit.csv' -DeleteScript 'delete-branches.ps1'
#>

param(
  [string]$Develop = 'develop',
  [string]$Master = 'master',
  [string]$Output = 'branch-pr-audit.csv',
  [string]$DeleteScript = 'delete-branches.ps1',
  [string]$Remote = 'origin'
)

function Fail([string]$msg) {
  Write-Host "ERROR: $msg" -ForegroundColor Red
  exit 1
}

# Requisitos mínimos
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Fail "git no está disponible en PATH. Instala Git for Windows."
}

if (-not $env:GITHUB_TOKEN) {
  Fail "No se encontró la variable de entorno GITHUB_TOKEN. Exporta tu token antes de ejecutar."
}

# Obtener remote origin URL y derivar owner/repo
$remoteUrl = (& git remote get-url $Remote) -join ''
if (-not $remoteUrl) {
  Fail "No se pudo obtener la URL del remote '$Remote'."
}

# Normalizar remote URL a owner/repo y host
$owner = $null
$repo = $null
$apiBase = "https://api.github.com"

if ($remoteUrl -match "github.com[:/]+([^/]+)/([^/]+?)(\.git)?$") {
  $owner = $matches[1]
  $repo = $matches[2]
  $apiBase = "https://api.github.com"
} elseif ($remoteUrl -match "([^@]+)@([^:]+):([^/]+)/([^/]+?)(\.git)?$") {
  # git@host:owner/repo.git
  $host = $matches[2]
  $owner = $matches[3]
  $repo = $matches[4]
  if ($host -ne "github.com") {
    # Asumir API enterprise en api/v3
    $apiBase = "https://$host/api/v3"
  }
} else {
  Write-Warning "No se pudo parsear owner/repo de '$remoteUrl'. Intentaré usar api.github.com y podría fallar si es un GitHub Enterprise."
}

if (-not $owner -or -not $repo) {
  Write-Warning "owner o repo no detectados correctamente. Output puede contener menos información sobre PRs."
}

# Preparar
Write-Host "Fetch remotos y prune..."
& git fetch --all --prune 2>$null

# CSV header
$header = "branch,upstream,exists_remote,merged_into_develop,merged_into_master,commits_not_in_develop,commits_not_in_master,last_commit_hash,last_commit_author,last_commit_date,pr_number,pr_state,pr_url,pr_base,pr_merged_at,ci_state"
Set-Content -Path $Output -Value $header -Encoding UTF8

# Delete script header (comentado por seguridad)
$delHeader = @"
# Script de borrado generado por branch-audit-gh.ps1
# Revisa cuidadosamente antes de descomentar los comandos.
# Para ejecutar después de revisar: powershell -ExecutionPolicy Bypass -File .\delete-branches.ps1
# Los comandos están comentados por seguridad.
"@
Set-Content -Path $DeleteScript -Value $delHeader -Encoding UTF8

# Obtener ramas locales
$branches = (& git for-each-ref --format='%(refname:short)' refs/heads/) | Where-Object { $_ -ne $null }

$candidates = @()
$total = 0

foreach ($b in $branches) {
  $total++
  if ($b -eq $Develop -or $b -eq $Master) { continue }

  # upstream
  $upstream = (& git for-each-ref --format='%(upstream:short)' "refs/heads/$b") -join ''
  $exists_remote = $false
  if ($upstream -ne '') { $exists_remote = $true }

  # commits exclusivos comparados a develop/master
  try {
    $countsDevRaw = (& git rev-list --left-right --count "$Develop...$b") 2>$null
    $countsDev = ($countsDevRaw -split '\s+') | Where-Object { $_ -ne '' }
  } catch { $countsDev = @('0','0') }
  if ($countsDev.Length -lt 2) { $countsDev = @('0','0') }
  $commitsNotInDevelop = [int]$countsDev[1]

  try {
    $countsMasterRaw = (& git rev-list --left-right --count "$Master...$b") 2>$null
    $countsMaster = ($countsMasterRaw -split '\s+') | Where-Object { $_ -ne '' }
  } catch { $countsMaster = @('0','0') }
  if ($countsMaster.Length -lt 2) { $countsMaster = @('0','0') }
  $commitsNotInMaster = [int]$countsMaster[1]

  $mergedDev = if ($commitsNotInDevelop -eq 0) { 'yes' } else { 'no' }
  $mergedMaster = if ($commitsNotInMaster -eq 0) { 'yes' } else { 'no' }

  # último commit
  try {
    $lastRaw = (& git log -1 --format='%H;%an;%ai' $b) -join ''
    if (-not $lastRaw) { $lastRaw = ";;" }
  } catch { $lastRaw = ";;" }
  $parts = $lastRaw -split ';',3
  $lastHash = $parts[0].Trim()
  $lastAuthor = if ($parts.Length -ge 2) { $parts[1].Trim() } else { '' }
  $lastDate = if ($parts.Length -ge 3) { $parts[2].Trim() } else { '' }

  # Info PR via GitHub API (si owner/repo disponibles)
  $pr_number = ''
  $pr_state = ''
  $pr_url = ''
  $pr_base = ''
  $pr_merged_at = ''

  if ($owner -and $repo) {
    # endpoint: GET /repos/{owner}/{repo}/pulls?head={owner}:{branch}&state=all
    $prApiUrl = "$apiBase/repos/$owner/$repo/pulls?head=$owner`:$b&state=all"
    try {
      $resp = Invoke-RestMethod -Headers @{ Authorization = "token $env:GITHUB_TOKEN"; "User-Agent"="branch-audit-script" } -Uri $prApiUrl -Method Get -ErrorAction Stop
      if ($resp -and $resp.Count -gt 0) {
        # tomar el PR más reciente (primero)
        $p = $resp[0]
        $pr_number = $p.number
        $pr_state = $p.state
        $pr_url = $p.html_url
        $pr_base = $p.base.ref
        $pr_merged_at = if ($p.merged_at) { $p.merged_at } else { '' }
      } else {
        # no PRs para esa rama
        $pr_state = 'none'
      }
    } catch {
      Write-Warning "No se pudo consultar PRs para $owner/$repo#$b via API: $($_.Exception.Message)"
      $pr_state = 'api_error'
    }
  } else {
    $pr_state = 'unknown'
  }

  # CI status para el último commit (estado agregado)
  $ci_state = ''
  if ($owner -and $repo -and $lastHash) {
    $statusUrl = "$apiBase/repos/$owner/$repo/commits/$lastHash/status"
    try {
      $sresp = Invoke-RestMethod -Headers @{ Authorization = "token $env:GITHUB_TOKEN"; "User-Agent"="branch-audit-script" } -Uri $statusUrl -Method Get -ErrorAction Stop
      if ($sresp -and $sresp.state) {
        $ci_state = $sresp.state
      } else {
        $ci_state = 'none'
      }
    } catch {
      # un fallback: checks API (may require scopes)
      try {
        $checksUrl = "$apiBase/repos/$owner/$repo/commits/$lastHash/check-suites"
        $ck = Invoke-RestMethod -Headers @{ Authorization = "token $env:GITHUB_TOKEN"; "User-Agent"="branch-audit-script" } -Uri $checksUrl -Method Get -ErrorAction Stop
        if ($ck -and $ck.total_count -gt 0) { $ci_state = 'check-suites' } else { $ci_state = 'unknown' }
      } catch {
        $ci_state = 'api_error'
      }
    }
  } else {
    $ci_state = 'unknown'
  }

  # Escapar comillas
  function esc($s) { if ($null -eq $s) { return "" } else { return $s -replace '"','""' } }

  $line = '"{0}","{1}","{2}","{3}","{4}","{5}","{6}","{7}","{8}","{9}","{10}","{11}","{12}","{13}","{14}"' -f `
    (esc $b), (esc $upstream), $exists_remote, $mergedDev, $mergedMaster, `
    $commitsNotInDevelop, $commitsNotInMaster, (esc $lastHash), (esc $lastAuthor), (esc $lastDate), `
    (esc $pr_number), (esc $pr_state), (esc $pr_url), (esc $pr_base), (esc $pr_merged_at), (esc $ci_state)

  Add-Content -Path $Output -Value $line -Encoding UTF8

  # Decidir candidato a borrar (reglas)
  # candidato si:
  #  - commitsNotInDevelop == 0 (ya contenido en develop), o
  #  - pr_state == 'closed' && pr_merged_at != ''  (PR mergeado)
  # NOTA: si está mergeado solo a master pero no a develop, lo marcamos para REVIEW (hotfix).
  $isCandidate = $false
  $note = ''
  if ($commitsNotInDevelop -eq 0) {
    $isCandidate = $true
    $note = "merged_into_$Develop"
  }
  if ($pr_state -eq 'closed' -and $pr_merged_at -ne '') {
    $isCandidate = $true
    if ($note -eq '') { $note = "pr_merged" } else { $note += ";pr_merged" }
  }
  if ($mergedMaster -eq 'yes' -and $mergedDev -eq 'no') {
    # hotfix directo a master: no lo borres automáticamente, agregar nota
    $note += ";hotfix_merged_to_master_only"
  }

  if ($isCandidate) {
    $candidates += [PSCustomObject]@{ branch=$b; upstream=$upstream; note=$note }
    # agregar comando comentado al delete script
    $cmds = @()
    $cmds += "# === Candidate: $b  ($note) ==="
    $cmds += "# git branch -d $b"
    if ($exists_remote) { $cmds += "# git push $Remote --delete $b" }
    $cmds += ""
    Add-Content -Path $DeleteScript -Value ($cmds -join "`n") -Encoding UTF8
  }
}

# Resumen
Write-Host "`nReporte generado en: $Output"
Write-Host "Script de borrado (dry-run) generado en: $DeleteScript"
Write-Host "Ramas escaneadas: $total"
Write-Host "Candidatas a borrado identificadas: $($candidates.Count)"

if ($candidates.Count -gt 0) {
  Write-Host "`nLista rápida de candidatas:"
  $candidates | ForEach-Object { Write-Host " - $($_.branch) `t $_.note" }
} else {
  Write-Host "No se encontraron candidatas claras a borrar."
}

Write-Host "`nSiguiente paso recomendado:"
Write-Host "1) Abre el CSV ($Output) y revisa cada fila."
Write-Host "2) Revisa el script de borrado ($DeleteScript). Los comandos están comentados. Descomenta y ejecuta manualmente cuando estés listo."
Write-Host "3) Si quieres que automatice el borrado (no recomendado sin revisión), puedo añadir una opción -AutoApply que ejecute los comandos (con confirmación)."

# Fin
