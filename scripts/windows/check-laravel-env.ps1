<#
.SYNOPSIS
  Valida entorno PHP y Composer para proyectos Laravel.
.DESCRIPTION
  Verifica versiones, configuración y extensiones requeridas.
  Ideal para diagnóstico antes de instalar o correr Laravel.
#>

Write-Host "=== Verificación del entorno para Laravel ===`n" -ForegroundColor Cyan

# --- PHP ---
if (Get-Command php -ErrorAction SilentlyContinue) {
    $phpVersion = php -v | Select-String "PHP"
    Write-Host "✔ PHP encontrado: $phpVersion" -ForegroundColor Green

    # php.ini
    $phpIni = (php --ini | Select-String "Loaded Configuration File").ToString().Split(":")[-1].Trim()
    Write-Host "Archivo php.ini cargado:`n  $phpIni`n"

    # extension_dir
    $extDir = php -i | Select-String "extension_dir" | ForEach-Object { $_.ToString().Split("=>")[-1].Trim() } | Select-Object -First 1
    Write-Host "Directorio de extensiones:`n  $extDir`n"

    # Extensiones requeridas
    $requiredExtensions = @("fileinfo", "curl", "mbstring", "openssl", "pdo_sqlite", "pdo_mysql", "xml", "bcmath", "ctype", "tokenizer")
    $loadedExtensions = php -m
    $missingExtensions = @()

    foreach ($ext in $requiredExtensions) {
        if ($loadedExtensions -match $ext) {
            Write-Host "✔ Extensión activa: $ext" -ForegroundColor Green
        } else {
            Write-Host "✖ Falta extensión: $ext" -ForegroundColor Yellow
            $missingExtensions += $ext
        }
    }

    # memory_limit y max_execution_time
    Write-Host "`nConfiguraciones importantes:`n" -ForegroundColor Cyan
    php -r "echo 'memory_limit: '.ini_get('memory_limit').PHP_EOL;"
    php -r "echo 'max_execution_time: '.ini_get('max_execution_time').PHP_EOL;"

} else {
    Write-Host "✖ PHP no encontrado en PATH. Instálalo con winget:" -ForegroundColor Red
    Write-Host "  winget install --id=PHP.PHP -e"
    exit 1
}

# --- Composer ---
Write-Host "`n--- Composer ---" -ForegroundColor Cyan
if (Get-Command composer -ErrorAction SilentlyContinue) {
    $composerVersion = composer --version
    Write-Host "✔ Composer encontrado: $composerVersion" -ForegroundColor Green

    # Probar diagnóstico de composer
    Write-Host "`nEjecutando composer diagnose..." -ForegroundColor Cyan
    composer diagnose
} else {
    Write-Host "✖ Composer no encontrado. Instálalo con winget:" -ForegroundColor Red
    Write-Host "  winget install --id=Composer.Composer -e"
    exit 1
}

# --- Laravel Installer ---
Write-Host "`n--- Laravel Installer ---" -ForegroundColor Cyan
$laravelInstaller = Get-Command laravel -ErrorAction SilentlyContinue
if ($laravelInstaller) {
    $laravelVersion = laravel --version
    Write-Host "✔ Laravel Installer disponible: $laravelVersion" -ForegroundColor Green
} else {
    Write-Host "✖ Laravel Installer no encontrado." -ForegroundColor Yellow
    Write-Host "  Puedes instalarlo con: composer global require laravel/installer`n"
}

# --- Resumen final ---
Write-Host "`n=== Resumen ===" -ForegroundColor Cyan
if ($missingExtensions.Count -eq 0) {
    Write-Host "✅ Todo correcto. El entorno está listo para Laravel." -ForegroundColor Green
} else {
    Write-Host "⚠ Faltan extensiones: $($missingExtensions -join ', ')" -ForegroundColor Yellow
    Write-Host "Edita el archivo php.ini en:`n  $phpIni`npara habilitarlas (quita el ';' en cada línea correspondiente)." -ForegroundColor Yellow
}

Write-Host "`n--- Fin del diagnóstico ---" -ForegroundColor Cyan
