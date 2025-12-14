<#
.SYNOPSIS
    Convierte imágenes PNG a WebP en múltiples tamaños para dispositivos responsive.
.DESCRIPTION
    Este script busca imágenes PNG en un directorio especificado,
    y genera versiones WebP optimizadas para Desktop, Tablet y Mobile.
    Utiliza ImageMagick para la conversión y optimización.
.PARAMETER Directorio
    Ruta del directorio que contiene las imágenes PNG a convertir.
.PARAMETER Calidad
    Calidad de compresión para las imágenes WebP (0-100). Por defecto es 85.
.EXAMPLE
    .\convertir-png-a-webp-para-blog.ps1 -Directorio "C:\Imagenes" -Calidad 90
    Convierte todas las imágenes PNG en "C:\Imagenes" a WebP con calidad 90.
.NOTES
    Asegúrate de tener ImageMagick instalado y 'magick.exe' en el PATH del sistema.
#>

param (
    [string]$Directorio = ".",
    [int]$Calidad = 85 # Ajusta la calidad (0-100)
)

# Configuración de dimensiones para cada dispositivo
$dimensiones = @{
    Desktop = @{ Width = 1920; Height = 1080; Suffix = "" }
    Tablet  = @{ Width = 1024; Height = 585; Suffix = "-tablet" }
    Mobile  = @{ Width = 600; Height = 343; Suffix = "-mobile" }
}

# Validar si ImageMagick está disponible
if (-not (Get-Command magick.exe -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick no está instalado o 'magick.exe' no está en el PATH."
    exit 1
}

# Obtener todos los archivos PNG del directorio
$imagenes = Get-ChildItem -Path $Directorio -Filter *.png

if ($imagenes.Count -eq 0) {
    Write-Host "No se encontraron imágenes PNG en $Directorio."
    exit 0
}

Write-Host "Iniciando conversión de $($imagenes.Count) imágenes..."
Write-Host "----------------------------------------"

foreach ($imagen in $imagenes) {
    $rutaOriginal = $imagen.FullName
    $nombreBase = [System.IO.Path]::GetFileNameWithoutExtension($rutaOriginal)
    $directorioBase = [System.IO.Path]::GetDirectoryName($rutaOriginal)
    
    Write-Host "`nProcesando: $($imagen.Name)"
    
    foreach ($tipo in $dimensiones.Keys) {
        $config = $dimensiones[$tipo]
        $nombreSalida = "$directorioBase\$nombreBase$($config.Suffix).webp"
        
        Write-Host "  -> Generando versión $tipo ($($config.Width)x$($config.Height))..."
        
        # Comando de conversión con redimensionamiento y optimización
        # -resize: redimensiona manteniendo aspect ratio y ajustando al tamaño especificado
        # -gravity center -extent: centra y recorta al tamaño exacto
        # -quality: calidad de compresión WebP
        # -define webp:method=6: máxima optimización (más lento pero mejor compresión)
        & magick "$rutaOriginal" `
            -resize "$($config.Width)x$($config.Height)^" `
            -gravity center `
            -extent "$($config.Width)x$($config.Height)" `
            -quality $Calidad `
            -define webp:method=6 `
            "$nombreSalida"
        
        if ($LASTEXITCODE -eq 0) {
            $tamano = (Get-Item $nombreSalida).Length / 1KB
            Write-Host "     ✓ Creado: $([System.IO.Path]::GetFileName($nombreSalida)) ($([math]::Round($tamano, 2)) KB)" -ForegroundColor Green
        } else {
            Write-Host "     ✗ Error al crear versión $tipo" -ForegroundColor Red
        }
    }
}

Write-Host "`n----------------------------------------"
Write-Host "Conversión completada. Imágenes WebP generadas en $Directorio." -ForegroundColor Cyan