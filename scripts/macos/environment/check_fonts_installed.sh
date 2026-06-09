#!/bin/bash

# Lista de fuentes que quieres validar
FONTS=(
  "Hack Nerd Font"
  "Skia"
  "Gill Sans"
  "Segoe WPC"
  "Segoe UI"
  "Ubuntu"
  "Droid Sans"
  "Iosevka"
  "Monaspace Krypton"
)

# Usa mdfind con kMDItemKind para buscar fuentes instaladas en macOS
check_font() {
  local font="$1"
  mdfind "kMDItemKind == 'Font' && kMDItemDisplayName == '$font'" >/dev/null 2>&1
  if [ $? -eq 0 ] && [ -n "$(mdfind "kMDItemKind == 'Font' && kMDItemDisplayName == '$font'")" ]; then
    echo "✔ $font instalada"
  else
    echo "✘ $font NO encontrada"
  fi
}

echo "Validando fuentes instaladas en macOS..."
echo

for f in "${FONTS[@]}"; do
  check_font "$f"
done

echo
echo "Listo."