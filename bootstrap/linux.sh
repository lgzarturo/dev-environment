#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# bootstrap/linux.sh
#
# Detecta la distribución Linux (Arch, Ubuntu, Fedora) y prepara el sistema
# para instalar dependencias básicas y ejecutar el Makefile.
# -----------------------------------------------------------------------------

set -euo pipefail

log() {
  printf "[bootstrap] %s\n" "$1"
}

fail() {
  printf "[bootstrap][ERROR] %s\n" "$1" >&2
  exit 1
}

# Detección de la distro
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO=$ID
  else
    fail "No se pudo detectar la distribución Linux"
  fi
}

# Instalación de paquetes básicos según distro
install_base_packages() {
  case "$DISTRO" in
    arch|manjaro)
      log "Instalando paquetes base en Arch Linux"
      sudo pacman -Syu --noconfirm git base-devel curl wget unzip tar make
      ;;
    ubuntu|debian)
      log "Instalando paquetes base en Ubuntu/Debian"
      sudo apt update
      sudo apt install -y git build-essential curl wget unzip tar make
      ;;
    fedora)
      log "Instalando paquetes base en Fedora"
      sudo dnf update -y
      sudo dnf install -y git @development-tools curl wget unzip tar make
      ;;
    *)
      fail "Distribución no soportada: $DISTRO"
      ;;
  esac
}

# Asegura que make está disponible
check_make() {
  if ! command -v make >/dev/null 2>&1; then
    fail "make no está instalado. Algo salió mal en la instalación de paquetes base."
  fi
}

main() {
  log "Detectando distribución Linux"
  detect_distro
  log "Distribución detectada: $DISTRO"

  log "Instalando paquetes base"
  install_base_packages

  log "Verificando que make esté disponible"
  check_make

  log "Bootstrap Linux completado. Ahora puedes ejecutar 'make <distro>'"
}

main "$@"
