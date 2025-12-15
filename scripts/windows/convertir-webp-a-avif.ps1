<#
.SYNOPSIS
    Convierte todas las imágenes WebP en un directorio especificado a formato AVIF utilizando ImageMagick.
.DESCRIPTION
    Este script busca imágenes WebP en un directorio dado y las convierte a AVIF con una calidad especificada.
.PARAMETER directorio
    Ruta del directorio que contiene las imágenes WebP a convertir.
.PARAMETER calidad
    Calidad de compresión para las imágenes AVIF (0-100). Por defecto es 60.
.EXAMPLE
    .\convertir-webp-a-avif.ps1 -directorio "C:\Imagenes" -calidad 70
    Convierte todas las imágenes WebP en "C:\Imagenes" a AVIF con calidad 70.
.NOTES
    Asegúrate de tener ImageMagick instalado y 'magick' en el PATH del sistema.
#>

param(
    [string]$directorio = ".",
    [int]$calidad = 60  # Calidad 0..100
)

# Verificar que ImageMagick esté instalado
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Host "Error: No se encontró 'magick' (ImageMagick) en el PATH."
    Write-Host "👉 Descárgalo desde: https://imagemagick.org/script/download.php"
    exit 1
}

$imagenes = Get-ChildItem -Path $directorio -Recurse -Include *.webp

if ($imagenes.Count -eq 0) {
    Write-Host "No se encontraron imágenes .webp."
    exit 0
}

foreach ($imagen in $imagenes) {
    $rutaAvif = [System.IO.Path]::ChangeExtension($imagen.FullName, ".avif")

    if (Test-Path $rutaAvif) {
        Write-Host "Ya existe: $rutaAvif — se omite."
        continue
    }

    Write-Host "Convirtiendo: $($imagen.Name) → $(Split-Path $rutaAvif -Leaf)"

    # Ejecuta la conversión con compresión AVIF
    & magick $imagen.FullName -quality $calidad -define heic:speed=6 $rutaAvif

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Convertida: $rutaAvif"
    } else {
        Write-Host "❌ Error al convertir: $($imagen.FullName)"
    }
}

Write-Host "`nConversión completada."
