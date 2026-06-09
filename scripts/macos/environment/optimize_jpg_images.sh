#!/bin/bash

# Directorio de salida
OUTPUT_DIR="optimized"

# Crear el directorio si no existe
mkdir -p "$OUTPUT_DIR"

# Recorre todos los archivos PNG del directorio actual
for f in *.{png,PNG,jpg,JPG,jpeg,JPEG}; do
  # Verifica que el archivo exista (evita errores si no hay PNGs)
  [ -e "$f" ] || continue

  # Nombre base del archivo sin extensión
  base=$(basename "$f")
  base_no_ext="${base%.*}"

  # Ruta de salida
  out="$OUTPUT_DIR/${base_no_ext}.jpg"

  echo "🖼️ Convirtiendo: $f → $out"

  # 1️⃣ Convertir PNG → JPG con compresión 70%
  sips -s format jpeg -s formatOptions 70 "$f" --out "$out" >/dev/null 2>&1

  # 2️⃣ Remover todos los metadatos con exiftool
  #    -overwrite_original  → reemplaza el archivo
  #    -all=                → borra todos los metadatos
  #    -quiet               → suprime la salida
  exiftool -all= -overwrite_original -quiet "$out"

  echo "✅ Optimizado y limpio: $out"
done

echo "🎉 Proceso completado. Archivos en '$OUTPUT_DIR'"
