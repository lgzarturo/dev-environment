#!/bin/bash

# =============================================================================
# macOS Development Environment Cleanup Script
# =============================================================================
# Limpia caches, archivos temporales y optimiza el sistema después de
# configurar el entorno de desarrollo
# =============================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/cleanup.log"
TOTAL_FREED=0

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

print_header() {
    echo -e "\n${PURPLE}=================================================================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${PURPLE}=================================================================================${NC}\n"
}

print_step() {
    echo -e "${CYAN}[PASO]${NC} $1"
    echo "[$(date)] PASO: $1" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    echo "[$(date)] ÉXITO: $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    echo "[$(date)] ADVERTENCIA: $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    echo "[$(date)] ERROR: $1" >> "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date)] INFO: $1" >> "$LOG_FILE"
}

# Función para calcular el tamaño de un directorio
get_size() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1 | head -1
    else
        echo "0B"
    fi
}

# Función para calcular el tamaño en bytes
get_size_bytes() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -s "$path" 2>/dev/null | cut -f1 | head -1
    else
        echo "0"
    fi
}

# Función para convertir bytes a formato legible
bytes_to_human() {
    local bytes=$1
    if [[ $bytes -gt 1073741824 ]]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [[ $bytes -gt 1048576 ]]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    elif [[ $bytes -gt 1024 ]]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# Función para limpiar directorio de forma segura
safe_cleanup() {
    local path="$1"
    local description="$2"
    local size_before=0
    local size_after=0
    
    if [[ -d "$path" ]]; then
        size_before=$(get_size_bytes "$path")
        print_step "Limpiando $description..."
        print_info "Tamaño antes: $(get_size "$path")"
        
        # Eliminar contenido pero mantener el directorio
        find "$path" -mindepth 1 -delete 2>/dev/null || true
        
        size_after=$(get_size_bytes "$path")
        local freed=$((size_before - size_after))
        TOTAL_FREED=$((TOTAL_FREED + freed))
        
        print_success "$description limpiado - Liberados: $(bytes_to_human $freed)"
    else
        print_info "$description no existe - Omitiendo"
    fi
}

# Función para eliminar archivos específicos
remove_files() {
    local pattern="$1"
    local description="$2"
    local count=0
    
    print_step "Eliminando $description..."
    
    # Usar find para contar y eliminar archivos
    if command -v find >/dev/null 2>&1; then
        count=$(find . -name "$pattern" -type f 2>/dev/null | wc -l | tr -d ' ')
        find . -name "$pattern" -type f -delete 2>/dev/null || true
    fi
    
    if [[ $count -gt 0 ]]; then
        print_success "$description eliminados: $count archivos"
    else
        print_info "No se encontraron $description"
    fi
}

# Verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# =============================================================================
# FUNCIONES DE LIMPIEZA
# =============================================================================

cleanup_homebrew() {
    if ! command_exists brew; then
        print_warning "Homebrew no está instalado - Omitiendo limpieza de Homebrew"
        return 0
    fi
    
    print_header "LIMPIEZA DE HOMEBREW"
    
    # Cache de Homebrew
    local brew_cache="$(brew --cache)"
    if [[ -d "$brew_cache" ]]; then
        local size_before=$(get_size_bytes "$brew_cache")
        print_step "Limpiando cache de Homebrew..."
        print_info "Ubicación: $brew_cache"
        print_info "Tamaño antes: $(get_size "$brew_cache")"
        
        brew cleanup --prune=all 2>/dev/null || true
        
        local size_after=$(get_size_bytes "$brew_cache")
        local freed=$((size_before - size_after))
        TOTAL_FREED=$((TOTAL_FREED + freed))
        
        print_success "Cache de Homebrew limpiado - Liberados: $(bytes_to_human $freed)"
    fi
    
    # Downloads de Homebrew
    local brew_downloads="$HOME/Library/Caches/Homebrew/downloads"
    safe_cleanup "$brew_downloads" "Downloads de Homebrew"
    
    # Logs de Homebrew
    local brew_logs="$HOME/Library/Logs/Homebrew"
    safe_cleanup "$brew_logs" "Logs de Homebrew"
    
    # Autoremove de paquetes huérfanos
    print_step "Eliminando dependencias huérfanas..."
    brew autoremove 2>/dev/null || true
    print_success "Dependencias huérfanas eliminadas"
}

cleanup_development_tools() {
    print_header "LIMPIEZA DE HERRAMIENTAS DE DESARROLLO"
    
    # Cache de npm
    if command_exists npm; then
        print_step "Limpiando cache de npm..."
        local npm_cache=$(npm config get cache 2>/dev/null || echo "$HOME/.npm")
        if [[ -d "$npm_cache" ]]; then
            local size_before=$(get_size "$npm_cache")
            npm cache clean --force 2>/dev/null || true
            print_success "Cache de npm limpiado - Era: $size_before"
        fi
    fi
    
    # Cache de yarn (si existe)
    if command_exists yarn; then
        print_step "Limpiando cache de yarn..."
        yarn cache clean 2>/dev/null || true
        print_success "Cache de yarn limpiado"
    fi
    
    # Cache de pip
    if command_exists pip3; then
        print_step "Limpiando cache de pip..."
        pip3 cache purge 2>/dev/null || true
        print_success "Cache de pip limpiado"
    fi
    
    # Cache de Python
    safe_cleanup "$HOME/Library/Caches/pip" "Cache de pip (alternativo)"
    safe_cleanup "$HOME/.cache/pip" "Cache de pip (Linux-style)"
    
    # Archivos .pyc
    print_step "Eliminando archivos .pyc de Python..."
    find "$HOME" -name "*.pyc" -delete 2>/dev/null || true
    find "$HOME" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    print_success "Archivos .pyc eliminados"
}

cleanup_neovim() {
    print_header "LIMPIEZA DE NEOVIM"
    
    # Cache de Neovim
    safe_cleanup "$HOME/.local/share/nvim" "Datos de Neovim"
    safe_cleanup "$HOME/.local/state/nvim" "Estado de Neovim"
    safe_cleanup "$HOME/.cache/nvim" "Cache de Neovim"
    
    # Logs de LSP
    safe_cleanup "$HOME/.local/state/nvim/lsp.log" "Logs de LSP"
    
    # Mason cache
    safe_cleanup "$HOME/.local/share/nvim/mason" "Cache de Mason"
    
    # Lazy.nvim cache
    safe_cleanup "$HOME/.local/share/nvim/lazy" "Cache de Lazy.nvim"
    
    print_info "Nota: Al abrir Neovim, los plugins se reinstalarán automáticamente"
}

cleanup_git() {
    print_header "LIMPIEZA DE GIT"
    
    if command_exists git; then
        # Limpiar repositorios git en el directorio de desarrollo
        local dev_dir="$HOME/Development"
        if [[ -d "$dev_dir" ]]; then
            print_step "Limpiando repositorios git en $dev_dir..."
            find "$dev_dir" -type d -name ".git" -exec sh -c 'cd "{}" && git gc --aggressive --prune=now' \; 2>/dev/null || true
            print_success "Repositorios git optimizados"
        fi
        
        # Limpiar cache global de git
        if [[ -d "$HOME/.gitconfig" ]]; then
            git config --global gc.auto 0 2>/dev/null || true
            print_success "Configuración de gc de git actualizada"
        fi
    fi
}

cleanup_system_cache() {
    print_header "LIMPIEZA DE CACHE DEL SISTEMA"
    
    # Cache de usuario
    safe_cleanup "$HOME/Library/Caches" "Cache de usuario (~/Library/Caches)"
    
    # Logs de usuario
    safe_cleanup "$HOME/Library/Logs" "Logs de usuario"
    
    # Archivos temporales del sistema
    safe_cleanup "/tmp" "Archivos temporales del sistema (/tmp)"
    
    # Cache de DNS
    if command_exists dscacheutil; then
        print_step "Limpiando cache de DNS..."
        sudo dscacheutil -flushcache 2>/dev/null || true
        print_success "Cache de DNS limpiado"
    fi
    
    # Papelera
    if [[ -d "$HOME/.Trash" ]]; then
        local trash_size=$(get_size "$HOME/.Trash")
        if [[ "$trash_size" != "0B" ]]; then
            print_step "Vaciando Papelera..."
            print_info "Tamaño de la Papelera: $trash_size"
            rm -rf "$HOME/.Trash/*" 2>/dev/null || true
            print_success "Papelera vaciada"
        else
            print_info "Papelera ya está vacía"
        fi
    fi
}

cleanup_setup_files() {
    print_header "LIMPIEZA DE ARCHIVOS DEL SCRIPT DE CONFIGURACIÓN"
    
    # Archivos de progreso del script anterior
    local setup_files=("setup.log" ".setup_progress" ".setup_skip")
    
    for file in "${setup_files[@]}"; do
        local filepath="${SCRIPT_DIR}/$file"
        if [[ -f "$filepath" ]]; then
            local size=$(ls -lh "$filepath" 2>/dev/null | awk '{print $5}' || echo "desconocido")
            rm "$filepath"
            print_success "Eliminado: $file ($size)"
        else
            print_info "$file no existe - Omitiendo"
        fi
    done
    
    # Backups de configuración antiguos
    print_step "Eliminando backups antiguos de configuración..."
    
    # Backups de .zshrc
    find "$HOME" -name ".zshrc.backup.*" -mtime +7 -delete 2>/dev/null || true
    
    # Backups de Neovim
    find "$HOME/.config" -name "nvim.backup.*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Backups antiguos eliminados"
}

cleanup_downloads() {
    print_header "LIMPIEZA DE DESCARGAS TEMPORALES"
    
    # Downloads de instaladores
    local downloads_dir="$HOME/Downloads"
    if [[ -d "$downloads_dir" ]]; then
        print_step "Buscando instaladores en Downloads..."
        
        # Eliminar instaladores .dmg antiguos
        find "$downloads_dir" -name "*.dmg" -mtime +7 -delete 2>/dev/null || true
        
        # Eliminar archivos .pkg antiguos
        find "$downloads_dir" -name "*.pkg" -mtime +7 -delete 2>/dev/null || true
        
        print_success "Instaladores antiguos eliminados"
    fi
}

optimize_system() {
    print_header "OPTIMIZACIÓN FINAL DEL SISTEMA"
    
    # Rebuilding de dyld cache (si es necesario)
    print_step "Actualizando cache del sistema..."
    sudo update_dyld_shared_cache 2>/dev/null || true
    print_success "Cache del sistema actualizado"
    
    # Forzar garbage collection
    if command_exists purge; then
        print_step "Liberando memoria no utilizada..."
        sudo purge 2>/dev/null || true
        print_success "Memoria liberada"
    fi
}

show_cleanup_summary() {
    print_header "RESUMEN DE LIMPIEZA"
    
    print_success "Limpieza completada exitosamente"
    print_info "Espacio total liberado: $(bytes_to_human $TOTAL_FREED)"
    
    # Mostrar espacio libre en disco
    local disk_free=$(df -h / | awk 'NR==2{print $4}')
    print_info "Espacio libre en disco: $disk_free"
    
    echo ""
    print_info "Archivos de log:"
    echo "  - Log de limpieza: $LOG_FILE"
    
    echo ""
    print_info "Recomendaciones post-limpieza:"
    echo "  1. Reinicia tu Mac para completar la optimización"
    echo "  2. La primera vez que abras Neovim, los plugins se reinstalarán"
    echo "  3. Ejecuta este script periódicamente para mantener el sistema limpio"
    
    echo ""
    print_success "¡Sistema limpio y optimizado! 🧹✨"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    # Limpiar pantalla y mostrar header
    clear
    print_header "LIMPIADOR DE SISTEMA macOS - ENTORNO DE DESARROLLO"
    
    # Inicializar archivo de log
    touch "$LOG_FILE"
    
    print_info "Iniciando limpieza del sistema..."
    print_info "Log: $LOG_FILE"
    print_warning "Algunos pasos pueden requerir contraseña de administrador"
    
    echo ""
    read -p "¿Continuar con la limpieza? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Limpieza cancelada por el usuario"
        exit 0
    fi
    
    # Ejecutar limpieza
    cleanup_homebrew
    cleanup_development_tools
    cleanup_neovim
    cleanup_git
    # cleanup_system_cache
    cleanup_setup_files
    cleanup_downloads
    optimize_system
    show_cleanup_summary
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi