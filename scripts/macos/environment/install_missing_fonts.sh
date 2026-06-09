#!/bin/bash

set -e

FONT_DIR="$HOME/Library/Fonts"
mkdir -p "$FONT_DIR"

echo "Instalando fuentes en macOS..."
echo

# Verifica Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew no está instalado. Instalándolo..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Actualizando Homebrew..."
brew update

echo
echo "Instalando fuentes disponibles en Homebrew..."
echo

brew_install_font() {
  local cask="$1"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    echo "✔ $cask ya instalada"
  else
    echo "→ Instalando $cask..."
    brew install --cask "$cask" || true
  fi
}

download_and_unzip() {
  local url="$1"
  local name="$2"

  echo "→ Descargando $name ..."
  tmp=$(mktemp -d)
  curl -L "$url" -o "$tmp/font.zip"
  unzip -o "$tmp/font.zip" -d "$tmp" >/dev/null 2>&1
  echo "Moviendo fuentes de $name..."
  cp "$tmp"/*.ttf "$tmp"/*.otf "$FONT_DIR" 2>/dev/null || true
  echo "✔ $name instalada"
  rm -rf "$tmp"
}

echo "### Hack Nerd Font"
brew_install_font "font-hack-nerd-font"

echo
echo "### Skia (ya viene con macOS)"
if [ -f "/System/Library/Fonts/Skia.ttf" ]; then
  echo "✔ Skia ya está en el sistema"
else
  echo "✘ Skia no se encuentra. Eso sería raro porque es parte del sistema"
fi

echo
echo "### Gill Sans (también parte del sistema)"
if ls /System/Library/Fonts/*Gill* >/dev/null 2>&1; then
  echo "✔ Gill Sans ya está en el sistema"
else
  echo "✘ Gill Sans no encontrada"
fi

echo
echo "### Segoe WPC / Segoe UI"
echo "→ Estas no están oficialmente disponibles para macOS"
download_and_unzip \
  "https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip" \
  "Segoe-like fallback (Cascadia Code)"

echo
echo "### Ubuntu"
brew_install_font "font-ubuntu"

echo
echo "### Droid Sans"
brew_install_font "font-droid-sans"

echo
echo "### Iosevka"
brew_install_font "font-iosevka"

echo
echo "### Monaspace"
brew_install_font "font-monaspace"

echo
echo "### Monaspace Frozen"
download_and_unzip \
  "https://github.com/githubnext/monaspace/releases/download/v1.301/monaspace-frozen-v1.301.zip" \
  "Monaspace Frozen"

echo
echo "Listo. Fuentes instaladas."
echo
echo "Proceso terminado."
echo "Nota: Reabre tus apps para que reconozcan las fuentes nuevas."