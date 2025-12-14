<#
.SYNOPSIS
  Script para reparar la instalación de pipenv en Windows 11.

.DESCRIPTION
  - Detecta versiones de Python instaladas.
  - Verifica si pipenv está instalado y en el PATH.
  - Instala o reinstala pipenv en la versión activa de Python.
  - Corrige el PATH del usuario si falta la carpeta Scripts.
  - Valida la instalación final.
#>

Write-Host "🔧 Iniciando reparación de pipenv..." -ForegroundColor Cyan

# 1. Detectar versiones de Python disponibles
$pythonVersions = & py -0p 2>$null
if (-not $pythonVersions) {
    Write-Host "❌ No se encontraron versiones de Python instaladas." -ForegroundColor Red
    exit 1
}

Write-Host "`n📦 Versiones de Python detectadas:"
Write-Host $pythonVersions

# 2. Determinar versión activa de Python
$pythonPath = (Get-Command python).Source
$pythonVersion = & python --version
Write-Host "`n✅ Python activo: $pythonVersion ($pythonPath)"

# 3. Verificar si pipenv está instalado para esa versión
Write-Host "`n🔍 Verificando instalación de pipenv..."
$pipenvCheck = & python -m pip show pipenv 2>$null

if (-not $pipenvCheck) {
    Write-Host "⚙️  Instalando pipenv para $pythonVersion..." -ForegroundColor Yellow
    & python -m pip install --force-reinstall pipenv
} else {
    Write-Host "✅ pipenv ya está instalado." -ForegroundColor Green
}

# 4. Verificar carpeta Scripts en el PATH
$userScriptsPath = "$env:APPDATA\Python\" + $pythonVersion.Split(" ")[1] + "\Scripts"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($currentPath -notmatch [regex]::Escape($userScriptsPath)) {
    Write-Host "`n🧭 Agregando Scripts al PATH del usuario..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$userScriptsPath", "User")
    Write-Host "✅ PATH actualizado. (Cierra y vuelve a abrir PowerShell)" -ForegroundColor Green
} else {
    Write-Host "✅ PATH correcto." -ForegroundColor Green
}

# 5. Validar ejecución de pipenv
Write-Host "`n🔎 Validando instalación..."
try {
    $version = & python -m pipenv --version
    Write-Host "✅ pipenv funcionando: $version" -ForegroundColor Green
} catch {
    Write-Host "❌ pipenv aún no responde correctamente." -ForegroundColor Red
    Write-Host "Puedes intentar ejecutar manualmente: py -3.12 -m pip install --user pipenv"
}

Write-Host "`n🎉 Proceso finalizado."
