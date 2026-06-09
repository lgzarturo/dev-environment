#!/bin/zsh

# Función para mostrar el uso del script
show_usage() {
    echo "Uso: $0 [directorio]"
    echo "Si no se proporciona un directorio, se usará el directorio actual."
}

# Verifica si se proporcionó un directorio como argumento
if [ $# -eq 0 ]; then
    directory="."
elif [ $# -eq 1 ]; then
    directory="$1"
else
    show_usage
    exit 1
fi

# Cambia al directorio especificado o usa el actual
cd "$directory" || { echo "😤 No se pudo acceder al directorio $directory"; exit 1; }

# Verifica si hay archivos .webp en el directorio
if ! ls *.webp &> /dev/null; then
    echo "🙈 No se encontraron archivos .webp en el directorio $(pwd)"
    exit 1
fi

# Procesa cada archivo .webp en el directorio
for image in *.webp; do
    # Extrae el nombre base del archivo (sin la extensión)
    base_name="${image%.webp}"
    
    # Crea las versiones redimensionadas
    magick "$image" -resize 600x "${base_name}-mobile.webp"
    magick "$image" -resize 1024x "${base_name}-tablet.webp"
    magick "$image" -resize 1920x "${base_name}-desktop.webp"
    
    echo "👷 Procesado: $image"
done

echo "🤖 Todas las imágenes han sido procesadas en el directorio $(pwd)"
