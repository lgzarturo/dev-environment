<#
.SYNOPSIS
    Convierte todas las imágenes PNG en un directorio especificado a formato WebP utilizando ImageMagick.
.DESCRIPTION
    Este script busca imágenes PNG en un directorio dado y las convierte a WebP con una calidad especificada.
.PARAMETER Directorio
    Ruta del directorio que contiene las imágenes PNG a convertir.
.PARAMETER Calidad
    Calidad de compresión para las imágenes WebP (0-100). Por defecto es 85.
.EXAMPLE
    .\convertir-png-a-webp.ps1 -Directorio "C:\Imagenes" -Calidad 90
    Convierte todas las imágenes PNG en "C:\Imagenes" a WebP con calidad 90.
.NOTES
    Asegúrate de tener ImageMagick instalado y 'magick.exe' en el PATH del sistema.    
#>

param (
    [string]$Directorio = ".",
    [int]$Calidad = 85 # Ajusta la calidad (0-100)
)

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

foreach ($imagen in $imagenes) {
    $rutaOriginal = $imagen.FullName
    $nombreWebp = [System.IO.Path]::ChangeExtension($rutaOriginal, ".webp")
    
    Write-Host "Convirtiendo: $rutaOriginal -> $nombreWebp"

    # Comando de conversión con optimización
    #& magick convert "$rutaOriginal" -quality $Calidad -define webp:method=6 "$nombreWebp"
	& magick "$rutaOriginal" -quality $Calidad -define webp:method=6 "$nombreWebp"

}

Write-Host "Conversión completada. Imágenes WebP generadas en $Directorio."
