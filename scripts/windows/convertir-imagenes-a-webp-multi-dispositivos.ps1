<#
.SYNOPSIS
    Convierte imágenes PNG a WebP en múltiples tamaños para optimización en dispositivos.
.DESCRIPTION
    Este script busca imágenes PNG en un directorio especificado,
    verifica si son cuadradas (ratio 1:1) y genera versiones WebP en
    varios tamaños (1024x1024, 512x512, 256x256, 192x192, 128x128).
    Utiliza ImageMagick para la conversión y optimización.
.PARAMETER Directorio
    Ruta del directorio que contiene las imágenes PNG a convertir.
.PARAMETER Calidad
    Calidad de compresión para las imágenes WebP (0-100). Por defecto es 85.
.EXAMPLE
    .\convertir-imagenes-a-webp-multi-dispositivos.ps1 -Directorio "C:\Imagenes" -Calidad 90
    Convierte todas las imágenes PNG en "C:\Imagenes" a WebP con calidad 90.
.NOTES
    Asegúrate de tener ImageMagick instalado y 'magick.exe' en el PATH del sistema.
#>

param (
    [string]$Directorio = ".",
    [int]$Calidad = 85 # Ajusta la calidad (0-100)
)

# Tamaños de salida
$tamaños = @(1024, 512, 256, 192, 128)

# Validar si ImageMagick está disponible
if (-not (Get-Command magick.exe -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick no está instalado o 'magick.exe' no está en el PATH."
    exit 1
}

# Obtener todos los archivos PNG del directorio
$imagenes = Get-ChildItem -Path $Directorio -Filter *.png

if ($imagenes.Count -eq 0) {
    Write-Host "No se encontraron imágenes PNG, JPG o WEBP en $Directorio."
    exit 0
}

foreach ($imagen in $imagenes) {
    $rutaOriginal = $imagen.FullName
    
    # Obtener dimensiones de la imagen
    $info = & magick identify -format "%w %h" "$rutaOriginal"
    $dimensiones = $info -split ' '
    $ancho = [int]$dimensiones[0]
    $alto = [int]$dimensiones[1]
    
    # Verificar si la imagen es cuadrada (ratio 1:1)
    if ($ancho -ne $alto) {
        Write-Host "Ignorando $($imagen.Name) - No es cuadrada (${ancho}x${alto})"
        continue
    }
    
    Write-Host "Procesando: $($imagen.Name) (${ancho}x${alto})"
    
    # Generar versiones en diferentes tamaños
    foreach ($tamaño in $tamaños) {
        $nombreBase = [System.IO.Path]::GetFileNameWithoutExtension($rutaOriginal)
        $directorioSalida = [System.IO.Path]::GetDirectoryName($rutaOriginal)
        $nombreWebp = Join-Path $directorioSalida "${nombreBase}_${tamaño}x${tamaño}.webp"
        
        Write-Host "  Creando: ${nombreBase}_${tamaño}x${tamaño}.webp"
        
        # Comando de conversión con redimensionamiento
        & magick "$rutaOriginal" -resize "${tamaño}x${tamaño}" -quality $Calidad -define webp:method=6 "$nombreWebp"
    }
}

Write-Host "Conversión completada. Imágenes WebP generadas en $Directorio."