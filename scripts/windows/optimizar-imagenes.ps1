<#
.SYNOPSIS
    Optimiza imágenes en un directorio especificado utilizando ImageMagick.
.DESCRIPTION
    Este script busca imágenes en formatos PNG, JPG, WEBP y AVIF en un directorio dado y las optimiza si se logra un ahorro de tamaño significativo (>= 4 KiB).
.PARAMETER directorio
    Ruta del directorio que contiene las imágenes a optimizar.
.PARAMETER calidad
    Calidad de compresión para la optimización (0-100). Por defecto es 78.
.PARAMETER minAhorroBytes
    Mínimo ahorro en bytes para reemplazar la imagen original. Por defecto es 4096 bytes (4 KiB).
.EXAMPLE
    .\optimizar-imagenes.ps1 -directorio "C:\Imagenes" -calidad 80
    Optimiza las imágenes en "C:\Imagenes" con calidad 80.
.NOTES
    Asegúrate de tener ImageMagick instalado y 'magick' en el PATH del sistema.
    Compatible con formatos PNG, JPG, WEBP y AVIF.
#>

param(
    [string]$directorio = ".",
    [int]$calidad = 78,
    [int]$minAhorroBytes = 4096
)

# Verifica que ImageMagick esté disponible
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Host "Error: No se encontró 'magick' (ImageMagick) en el PATH."
    Write-Host "👉 Instálalo desde: https://imagemagick.org/script/download.php"
    exit 1
}

# Extensiones soportadas
$extensiones = @("*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif")

# Buscar imágenes
$imagenes = Get-ChildItem -Path $directorio -Recurse -Include $extensiones -File

if ($imagenes.Count -eq 0) {
    Write-Host "No se encontraron imágenes para optimizar."
    exit 0
}

foreach ($imagen in $imagenes) {
    $original = $imagen.FullName
    $temp = "$($imagen.DirectoryName)\temp_$($imagen.Name)"

    Write-Host "Analizando: $($imagen.Name)"

    # Detectar tipo de formato
    $ext = $imagen.Extension.ToLower()
    $params = @()

    switch ($ext) {
        ".jpg" { $params = @("-quality", $calidad, "-strip") }
        ".jpeg" { $params = @("-quality", $calidad, "-strip") }
        ".png"  { $params = @("-strip", "-quality", $calidad) }
        ".webp" { $params = @("-quality", $calidad, "-define", "webp:method=6") }
        ".avif" { $params = @("-quality", $calidad, "-define", "heic:speed=6") }
        default { Write-Host "❌ Formato no soportado: $ext"; continue }
    }

    # Crear versión temporal optimizada
    & magick $original @params $temp

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $temp)) {
        Write-Host "❌ Error al procesar $($imagen.Name)"
        continue
    }

    # Compara tamaños
    $tamanoOriginal = (Get-Item $original).Length
    $tamanoOptimizado = (Get-Item $temp).Length
    $ahorro = $tamanoOriginal - $tamanoOptimizado

    if ($ahorro -ge $minAhorroBytes) {
        # Reemplaza la imagen original
        Move-Item -Force $temp $original
        $ahorroKiB = [math]::Round($ahorro / 1024, 2)
        Write-Host "✅ Optimizada: $($imagen.Name) → ahorro de $ahorroKiB KiB"
    } else {
        # Si el ahorro no es suficiente, descarta el temporal
        Remove-Item $temp -Force
        Write-Host "⚪ Sin cambios: $($imagen.Name) (ahorro menor a 4 KiB)"
    }
}

Write-Host "`nOptimización completada."
