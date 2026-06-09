#!/bin/bash

# Directorio actual o pasado como argumento
INPUT_DIR="${1:-.}"
OUTPUT_DIR="${INPUT_DIR}/output_jpg"
mkdir -p "$OUTPUT_DIR"

# Opción: forzar relación 16:9 (usar --force-16-9 al ejecutar)
FORCE_16_9=false
if [[ "$2" == "--force-16-9" ]]; then
  FORCE_16_9=true
fi

echo "Convirtiendo SVG a JPG en 4K..."
echo "Directorio de entrada: $INPUT_DIR"
echo "Directorio de salida : $OUTPUT_DIR"
echo "Forzar 16:9          : $FORCE_16_9"

for file in "$INPUT_DIR"/*.svg; do
  [ -e "$file" ] || continue  # evita error si no hay SVGs
  filename=$(basename -- "$file")
  name="${filename%.*}"
  output="$OUTPUT_DIR/${name}_4k.jpg"

  echo "Procesando: $file → $output"

  if $FORCE_16_9; then
    # Intentar con ImageMagick primero
    if magick -density 384 "$file" \
      -resize 3840x2160^ \
      -gravity center -extent 3840x2160 \
      -quality 100 "$output" 2>/dev/null; then
      echo "✔ Convertido con ImageMagick (16:9)"
    else
      echo "⚠ Error con ImageMagick, intentando con Inkscape..."
      if inkscape "$file" \
        --export-type=jpg \
        --export-filename="$output" \
        --export-width=3840 --export-height=2160 2>/dev/null; then
        echo "✔ Convertido con Inkscape (16:9 forzado por recorte posterior)"
        # Recortar a 16:9 exacto con magick
        magick "$output" -resize 3840x2160^ -gravity center -extent 3840x2160 "$output"
      else
        echo "❌ Error: no se pudo convertir $file"
      fi
    fi
  else
    # Mantener proporciones originales
    if magick -density 384 "$file" \
      -resize 3840x2160 \
      -quality 100 "$output" 2>/dev/null; then
      echo "✔ Convertido con ImageMagick"
    else
      echo "⚠ Error con ImageMagick, intentando con Inkscape..."
      if inkscape "$file" \
        --export-type=jpg \
        --export-filename="$output" \
        --export-width=3840 --export-height=2160 2>/dev/null; then
        echo "✔ Convertido con Inkscape"
      else
        echo "❌ Error: no se pudo convertir $file"
      fi
    fi
  fi
done

echo "✅ Conversión completada. Archivos en: $OUTPUT_DIR"