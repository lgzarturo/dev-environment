#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# symlink_dotfiles.sh
#
# Responsabilidad única:
# Crear symlinks desde el repositorio hacia $HOME de forma segura e idempotente.
#
# Reglas:
# - No sobrescribe archivos existentes sin respaldo
# - Es seguro ejecutarlo múltiples veces
# - Funciona en Linux y macOS
# - En Windows solo se usa desde WSL o Git Bash (no PowerShell)
# -----------------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOTFILES_DIR="$REPO_ROOT/dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup"

log() {
  printf "[dotfiles] %s\n" "$1"
}

warn() {
  printf "[dotfiles][WARN] %s\n" "$1"
}

fail() {
  printf "[dotfiles][ERROR] %s\n" "$1" >&2
  exit 1
}

ensure_backup_dir() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log "Creando directorio de respaldo en $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
  fi
}

backup_existing() {
  local target="$1"
  local base
  base="$(basename "$target")"

  if [[ -e "$target" && ! -L "$target" ]]; then
    ensure_backup_dir
    log "Respaldando $target"
    mv "$target" "$BACKUP_DIR/$base"
  fi
}

create_symlink() {
  local source="$1"
  local target="$2"

  if [[ -L "$target" ]]; then
    local current
    current="$(readlink "$target")"

    if [[ "$current" == "$source" ]]; then
      log "Symlink correcto: $target"
      return
    else
      warn "Symlink incorrecto en $target, reemplazando"
      rm "$target"
    fi
  elif [[ -e "$target" ]]; then
    backup_existing "$target"
  fi

  log "Creando symlink: $target → $source"
  ln -s "$source" "$target"
}

link_tree() {
  local base_dir="$1"

  if [[ ! -d "$base_dir" ]]; then
    return
  fi

  find "$base_dir" -type f | while read -r file; do
    local relative
    relative="${file#$DOTFILES_DIR/}"

    local target="$HOME/$relative"
    local target_dir
    target_dir="$(dirname "$target")"

    if [[ ! -d "$target_dir" ]]; then
      mkdir -p "$target_dir"
    fi

    create_symlink "$file" "$target"
  done
}

main() {
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    fail "No se encontró el directorio dotfiles"
  fi

  log "Iniciando enlace de dotfiles"
  link_tree "$DOTFILES_DIR"
  log "Dotfiles enlazados correctamente"
}

main "$@"
