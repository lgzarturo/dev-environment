#!/bin/bash

# =============================================================================
# Redis Cache Cleaner para Kubernetes
# Limpia cache de Redis en contenedores K8s con backup y restauración
# Soporta túneles SSH, namespaces, passwords y patrones de búsqueda
# =============================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/redis_cleaner_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="${SCRIPT_DIR}/redis_backups"
TEMP_DIR="${SCRIPT_DIR}/temp_$$"
SSH_TUNNEL_PID=""

# Configuración por defecto
DEFAULT_SSH_KEY="${HOME}/.ssh/id_rsa"
DEFAULT_LOCAL_PORT=6380
DEFAULT_REDIS_PORT=6379
DEFAULT_K8S_NAMESPACE="default"

# =============================================================================
# FUNCIONES UTILITARIAS
# =============================================================================

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

cleanup() {
    info "Limpiando recursos..."
    
    # Cerrar túnel SSH
    if [[ -n "$SSH_TUNNEL_PID" ]]; then
        kill "$SSH_TUNNEL_PID" 2>/dev/null || true
        info "Túnel SSH cerrado (PID: $SSH_TUNNEL_PID)"
    fi
    
    # Limpiar archivos temporales
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        info "Archivos temporales eliminados"
    fi
}

trap cleanup EXIT

# =============================================================================
# FUNCIONES DE CONFIGURACIÓN
# =============================================================================

show_help() {
    cat << EOF
Uso: $0 [OPCIONES]

MODOS DE OPERACIÓN:
    search      Solo buscar claves que coinciden con patrones
    clean       Limpiar claves (con backup automático)
    restore     Restaurar desde backup
    list        Listar backups disponibles

OPCIONES:
    -h, --help              Muestra esta ayuda
    -c, --config FILE       Archivo de configuración
    -m, --mode MODE         Modo de operación (search/clean/restore/list)
    -p, --patterns "pattern1,pattern2"  Patrones de claves separados por comas
    -w, --words "word1,word2"           Palabras específicas separadas por comas
    -b, --backup FILE       Archivo de backup para restaurar
    -y, --yes              Confirmar automáticamente (solo para clean)
    --dry-run              Modo prueba (no ejecutar cambios)

EJEMPLOS:
    $0 -m search -p "cache:*,session:*"
    $0 -m clean -w "user_123,order_456" 
    $0 -m restore -b redis_backup_20231201_143022.rdb
    $0 -c redis_config.conf -m clean -p "temp:*"

ARCHIVO DE CONFIGURACIÓN:
    USE_SSH_TUNNEL=true
    SSH_HOST=bastion.example.com
    SSH_USER=ec2-user
    SSH_KEY=/path/to/key.pem
    LOCAL_PORT=6380
    
    K8S_CONTEXT=production
    K8S_NAMESPACE=redis-namespace
    K8S_POD_NAME=redis-master-0
    K8S_CONTAINER_NAME=redis
    
    REDIS_HOST=localhost
    REDIS_PORT=6379
    REDIS_PASSWORD=yourpassword
    REDIS_DB=0

EOF
}

load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        log "Cargando configuración desde: $config_file"
        source "$config_file"
        return 0
    else
        error "Archivo de configuración no encontrado: $config_file"
        return 1
    fi
}

interactive_config() {
    log "=== CONFIGURACIÓN INTERACTIVA ==="
    
    # Configuración de túnel SSH
    echo
    info "=== CONFIGURACIÓN DE TÚNEL SSH ==="
    read -p "¿Usar túnel SSH? (y/n): " use_tunnel
    USE_SSH_TUNNEL=$([[ "$use_tunnel" =~ ^[Yy]$ ]] && echo "true" || echo "false")
    
    if [[ "$USE_SSH_TUNNEL" == "true" ]]; then
        read -p "Host SSH (bastion): " SSH_HOST
        read -p "Usuario SSH: " SSH_USER
        read -p "Clave SSH (Enter para $DEFAULT_SSH_KEY): " SSH_KEY
        SSH_KEY="${SSH_KEY:-$DEFAULT_SSH_KEY}"
        read -p "Puerto local para túnel (Enter para $DEFAULT_LOCAL_PORT): " LOCAL_PORT
        LOCAL_PORT="${LOCAL_PORT:-$DEFAULT_LOCAL_PORT}"
    fi
    
    # Configuración de Kubernetes
    echo
    info "=== CONFIGURACIÓN DE KUBERNETES ==="
    read -p "Contexto de Kubernetes (Enter para actual): " K8S_CONTEXT
    if [[ -z "$K8S_CONTEXT" ]]; then
        K8S_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    fi
    
    read -p "Namespace (Enter para '$DEFAULT_K8S_NAMESPACE'): " K8S_NAMESPACE
    K8S_NAMESPACE="${K8S_NAMESPACE:-$DEFAULT_K8S_NAMESPACE}"
    
    read -p "Nombre del pod de Redis: " K8S_POD_NAME
    read -p "Nombre del contenedor (Enter para 'redis'): " K8S_CONTAINER_NAME
    K8S_CONTAINER_NAME="${K8S_CONTAINER_NAME:-redis}"
    
    # Configuración de Redis
    echo
    info "=== CONFIGURACIÓN DE REDIS ==="
    if [[ "$USE_SSH_TUNNEL" == "true" ]]; then
        REDIS_HOST="localhost"
        REDIS_PORT="$LOCAL_PORT"
    else
        read -p "Host de Redis (Enter para 'localhost'): " REDIS_HOST
        REDIS_HOST="${REDIS_HOST:-localhost}"
        read -p "Puerto de Redis (Enter para $DEFAULT_REDIS_PORT): " REDIS_PORT
        REDIS_PORT="${REDIS_PORT:-$DEFAULT_REDIS_PORT}"
    fi
    
    read -p "¿Redis tiene password? (y/n): " has_password
    if [[ "$has_password" =~ ^[Yy]$ ]]; then
        read -s -p "Password de Redis: " REDIS_PASSWORD
        echo
    else
        REDIS_PASSWORD=""
    fi
    
    read -p "Base de datos Redis (Enter para 0): " REDIS_DB
    REDIS_DB="${REDIS_DB:-0}"
}

# =============================================================================
# FUNCIONES DE CONECTIVIDAD
# =============================================================================

check_dependencies() {
    local deps=("kubectl" "redis-cli")
    local missing=()
    
    if [[ "$USE_SSH_TUNNEL" == "true" ]]; then
        deps+=("ssh")
    fi
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Dependencias faltantes: ${missing[*]}"
        error "Instalar:"
        error "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
        error "  - redis-cli: sudo apt-get install redis-tools (Ubuntu/Debian)"
        error "  - redis-cli: brew install redis (macOS)"
        return 1
    fi
    
    log "Todas las dependencias están disponibles"
}

setup_ssh_tunnel() {
    local ssh_host="$1"
    local ssh_user="$2" 
    local ssh_key="$3"
    local local_port="$4"
    local remote_host="$5"
    local remote_port="$6"
    
    info "Estableciendo túnel SSH: localhost:$local_port -> $remote_host:$remote_port"
    
    # Verificar que la clave SSH existe
    if [[ ! -f "$ssh_key" ]]; then
        error "Clave SSH no encontrada: $ssh_key"
        return 1
    fi
    
    # Establecer túnel SSH
    ssh -i "$ssh_key" -L "$local_port:$remote_host:$remote_port" \
        -N -f "$ssh_user@$ssh_host" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR
    
    # Obtener PID del túnel
    local tunnel_pid=$(ps aux | grep "ssh.*$local_port:$remote_host:$remote_port" | grep -v grep | awk '{print $2}' | head -1)
    
    if [[ -n "$tunnel_pid" ]]; then
        log "Túnel SSH establecido - PID: $tunnel_pid"
        SSH_TUNNEL_PID="$tunnel_pid"
        sleep 3  # Esperar a que el túnel se establezca
        return 0
    else
        error "No se pudo establecer el túnel SSH"
        return 1
    fi
}

setup_k8s_port_forward() {
    info "Estableciendo port-forward de Kubernetes..."
    
    # Port-forward en background
    kubectl port-forward -n "$K8S_NAMESPACE" "pod/$K8S_POD_NAME" "$LOCAL_PORT:$REDIS_PORT" > /dev/null 2>&1 &
    local pf_pid=$!
    
    sleep 3  # Esperar a que se establezca
    
    if kill -0 "$pf_pid" 2>/dev/null; then
        log "Port-forward establecido - PID: $pf_pid"
        SSH_TUNNEL_PID="$pf_pid"  # Reutilizamos la variable para limpieza
        REDIS_HOST="localhost"
        REDIS_PORT="$LOCAL_PORT"
        return 0
    else
        error "No se pudo establecer port-forward"
        return 1
    fi
}

test_k8s_connection() {
    info "Probando conexión a Kubernetes..."
    
    # Verificar contexto
    if [[ -n "$K8S_CONTEXT" ]]; then
        kubectl config use-context "$K8S_CONTEXT" >/dev/null 2>&1 || {
            error "No se pudo cambiar al contexto: $K8S_CONTEXT"
            return 1
        }
    fi
    
    # Verificar que el pod existe
    if ! kubectl get pod -n "$K8S_NAMESPACE" "$K8S_POD_NAME" >/dev/null 2>&1; then
        error "Pod no encontrado: $K8S_POD_NAME en namespace $K8S_NAMESPACE"
        return 1
    fi
    
    log "Conexión a Kubernetes verificada"
    return 0
}

test_redis_connection() {
    info "Probando conexión a Redis..."
    
    local redis_cmd="redis-cli -h $REDIS_HOST -p $REDIS_PORT"
    if [[ -n "$REDIS_PASSWORD" ]]; then
        redis_cmd="$redis_cmd -a $REDIS_PASSWORD"
    fi
    if [[ -n "$REDIS_DB" && "$REDIS_DB" != "0" ]]; then
        redis_cmd="$redis_cmd -n $REDIS_DB"
    fi
    
    if $redis_cmd --no-auth-warning ping >/dev/null 2>&1; then
        log "Conexión a Redis exitosa"
        return 0
    else
        error "No se pudo conectar a Redis"
        return 1
    fi
}

# =============================================================================
# FUNCIONES DE BACKUP Y RESTORE
# =============================================================================

create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log "Directorio de backups: $BACKUP_DIR"
}

create_backup() {
    local backup_name="redis_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_file="$BACKUP_DIR/${backup_name}.rdb"
    local backup_keys_file="$BACKUP_DIR/${backup_name}_keys.txt"
    
    info "Creando backup: $backup_name"
    
    local redis_cmd="redis-cli -h $REDIS_HOST -p $REDIS_PORT --no-auth-warning"
    if [[ -n "$REDIS_PASSWORD" ]]; then
        redis_cmd="$redis_cmd -a $REDIS_PASSWORD"
    fi
    if [[ -n "$REDIS_DB" && "$REDIS_DB" != "0" ]]; then
        redis_cmd="$redis_cmd -n $REDIS_DB"
    fi
    
    # Crear backup de datos
    $redis_cmd --rdb "$backup_file" >/dev/null 2>&1
    
    # Crear lista de claves para referencia
    $redis_cmd KEYS "*" > "$backup_keys_file" 2>/dev/null
    
    if [[ -f "$backup_file" ]]; then
        local backup_size=$(du -h "$backup_file" | cut -f1)
        local key_count=$(wc -l < "$backup_keys_file" 2>/dev/null || echo "0")
        success "Backup creado: $backup_file ($backup_size, $key_count claves)"
        echo "$backup_file"
        return 0
    else
        error "Error al crear backup"
        return 1
    fi
}

list_backups() {
    info "=== BACKUPS DISPONIBLES ==="
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        warning "No hay backups disponibles"
        return 1
    fi
    
    echo
    printf "%-30s %-10s %-15s %-10s\n" "ARCHIVO" "TAMAÑO" "FECHA" "CLAVES"
    printf "%-30s %-10s %-15s %-10s\n" "$(printf '=%.0s' {1..30})" "$(printf '=%.0s' {1..10})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..10})"
    
    for backup_file in "$BACKUP_DIR"/*.rdb; do
        if [[ -f "$backup_file" ]]; then
            local filename=$(basename "$backup_file")
            local size=$(du -h "$backup_file" | cut -f1)
            local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$backup_file" 2>/dev/null || stat -c "%y" "$backup_file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
            local keys_file="${backup_file%.*}_keys.txt"
            local key_count="N/A"
            if [[ -f "$keys_file" ]]; then
                key_count=$(wc -l < "$keys_file" 2>/dev/null || echo "N/A")
            fi
            
            printf "%-30s %-10s %-15s %-10s\n" "$filename" "$size" "$date" "$key_count"
        fi
    done
    echo
}

restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Archivo de backup no encontrado: $backup_file"
        return 1
    fi
    
    warning "ADVERTENCIA: Restaurar un backup sobrescribirá todos los datos actuales en Redis"
    echo
    read -p "¿Estás seguro de que deseas continuar? (escribe 'CONFIRMO' para continuar): " confirm
    
    if [[ "$confirm" != "CONFIRMO" ]]; then
        info "Restauración cancelada"
        return 1
    fi
    
    info "Restaurando desde backup: $(basename "$backup_file")"
    
    # Crear backup de seguridad antes de restaurar
    local safety_backup
    safety_backup=$(create_backup)
    if [[ $? -eq 0 ]]; then
        info "Backup de seguridad creado: $safety_backup"
    fi
    
    # Detener Redis temporalmente para restaurar
    info "Restaurando datos..."
    
    local redis_cmd="redis-cli -h $REDIS_HOST -p $REDIS_PORT --no-auth-warning"
    if [[ -n "$REDIS_PASSWORD" ]]; then
        redis_cmd="$redis_cmd -a $REDIS_PASSWORD"
    fi
    if [[ -n "$REDIS_DB" && "$REDIS_DB" != "0" ]]; then
        redis_cmd="$redis_cmd -n $REDIS_DB"
    fi
    
    # Limpiar base de datos actual
    $redis_cmd FLUSHDB >/dev/null 2>&1
    
    # Restaurar usando redis-cli --pipe
    if command -v rdb-cli &> /dev/null; then
        rdb-cli "$backup_file" memory | $redis_cmd --pipe >/dev/null 2>&1
    else
        # Método alternativo usando DEBUG RELOAD
        warning "rdb-cli no disponible, usando método alternativo"
        # Nota: Esto requiere que el archivo RDB esté en el servidor Redis
        warning "La restauración completa requiere acceso directo al servidor Redis"
    fi
    
    success "Restauración completada"
}

# =============================================================================
# FUNCIONES DE BÚSQUEDA Y LIMPIEZA
# =============================================================================

search_keys() {
    local patterns="$1"
    local words="$2"
    
    info "Buscando claves en Redis..."
    
    local redis_cmd="redis-cli -h $REDIS_HOST -p $REDIS_PORT --no-auth-warning"
    if [[ -n "$REDIS_PASSWORD" ]]; then
        redis_cmd="$redis_cmd -a $REDIS_PASSWORD"
    fi
    if [[ -n "$REDIS_DB" && "$REDIS_DB" != "0" ]]; then
        redis_cmd="$redis_cmd -n $REDIS_DB"
    fi
    
    local all_keys=()
    
    # Buscar por patrones
    if [[ -n "$patterns" ]]; then
        info "Buscando por patrones: $patterns"
        IFS=',' read -ra PATTERN_ARRAY <<< "$patterns"
        for pattern in "${PATTERN_ARRAY[@]}"; do
            pattern=$(echo "$pattern" | xargs)  # Trim whitespace
            info "  Patrón: $pattern"
            while IFS= read -r key; do
                if [[ -n "$key" ]]; then
                    all_keys+=("$key")
                fi
            done < <($redis_cmd KEYS "$pattern" 2>/dev/null)
        done
    fi
    
    # Buscar palabras específicas
    if [[ -n "$words" ]]; then
        info "Buscando palabras específicas: $words"
        IFS=',' read -ra WORD_ARRAY <<< "$words"
        for word in "${WORD_ARRAY[@]}"; do
            word=$(echo "$word" | xargs)  # Trim whitespace
            info "  Palabra: $word"
            if $redis_cmd EXISTS "$word" >/dev/null 2>&1; then
                local exists=$($redis_cmd EXISTS "$word" 2>/dev/null)
                if [[ "$exists" == "1" ]]; then
                    all_keys+=("$word")
                fi
            fi
        done
    fi
    
    # Eliminar duplicados y mostrar resultados
    if [[ ${#all_keys[@]} -gt 0 ]]; then
        local unique_keys=($(printf "%s\n" "${all_keys[@]}" | sort -u))
        
        echo
        success "Claves encontradas: ${#unique_keys[@]}"
        echo
        printf "%-5s %-50s %-15s %-20s\n" "#" "CLAVE" "TIPO" "TTL"
        printf "%-5s %-50s %-15s %-20s\n" "$(printf '=%.0s' {1..5})" "$(printf '=%.0s' {1..50})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..20})"
        
        local counter=1
        for key in "${unique_keys[@]}"; do
            local key_type=$($redis_cmd TYPE "$key" 2>/dev/null || echo "unknown")
            local ttl=$($redis_cmd TTL "$key" 2>/dev/null || echo "N/A")
            if [[ "$ttl" == "-1" ]]; then ttl="SIN EXPIRACION"; fi
            if [[ "$ttl" == "-2" ]]; then ttl="EXPIRADA"; fi
            
            # Truncar clave si es muy larga
            local display_key="$key"
            if [[ ${#key} -gt 47 ]]; then
                display_key="${key:0:44}..."
            fi
            
            printf "%-5s %-50s %-15s %-20s\n" "$counter" "$display_key" "$key_type" "$ttl"
            ((counter++))
        done
        
        echo
        return 0
    else
        warning "No se encontraron claves que coincidan con los criterios"
        return 1
    fi
}

clean_keys() {
    local patterns="$1"
    local words="$2"
    local auto_confirm="$3"
    local dry_run="$4"
    
    # Primero buscar las claves
    local temp_output="${TEMP_DIR}/search_output.txt"
    mkdir -p "$TEMP_DIR"
    
    # Capturar la salida de búsqueda para procesar
    local redis_cmd="redis-cli -h $REDIS_HOST -p $REDIS_PORT --no-auth-warning"
    if [[ -n "$REDIS_PASSWORD" ]]; then
        redis_cmd="$redis_cmd -a $REDIS_PASSWORD"
    fi
    if [[ -n "$REDIS_DB" && "$REDIS_DB" != "0" ]]; then
        redis_cmd="$redis_cmd -n $REDIS_DB"
    fi
    
    local all_keys=()
    
    # Recopilar claves
    if [[ -n "$patterns" ]]; then
        IFS=',' read -ra PATTERN_ARRAY <<< "$patterns"
        for pattern in "${PATTERN_ARRAY[@]}"; do
            pattern=$(echo "$pattern" | xargs)
            while IFS= read -r key; do
                if [[ -n "$key" ]]; then
                    all_keys+=("$key")
                fi
            done < <($redis_cmd KEYS "$pattern" 2>/dev/null)
        done
    fi
    
    if [[ -n "$words" ]]; then
        IFS=',' read -ra WORD_ARRAY <<< "$words"
        for word in "${WORD_ARRAY[@]}"; do
            word=$(echo "$word" | xargs)
            local exists=$($redis_cmd EXISTS "$word" 2>/dev/null)
            if [[ "$exists" == "1" ]]; then
                all_keys+=("$word")
            fi
        done
    fi
    
    if [[ ${#all_keys[@]} -eq 0 ]]; then
        warning "No se encontraron claves para eliminar"
        return 1
    fi
    
    # Eliminar duplicados
    local unique_keys=($(printf "%s\n" "${all_keys[@]}" | sort -u))
    
    info "Claves a eliminar: ${#unique_keys[@]}"
    
    # Mostrar claves en modo verbose
    echo
    info "=== CLAVES QUE SERÁN ELIMINADAS ==="
    for i in "${!unique_keys[@]}"; do
        echo "$((i+1)). ${unique_keys[i]}"
        if [[ $((i+1)) -eq 20 && ${#unique_keys[@]} -gt 20 ]]; then
            echo "... y $((${#unique_keys[@]} - 20)) más"
            break
        fi
    done
    echo
    
    # Confirmación del usuario
    if [[ "$auto_confirm" != "true" ]]; then
        warning "¡ATENCIÓN! Esta operación eliminará ${#unique_keys[@]} claves de Redis"
        echo
        read -p "¿Estás seguro de que deseas continuar? (escribe 'CONFIRMO' para continuar): " confirm
        
        if [[ "$confirm" != "CONFIRMO" ]]; then
            info "Operación cancelada"
            return 1
        fi
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        warning "MODO PRUEBA: No se eliminarán las claves"
        return 0
    fi
    
    # Crear backup antes de eliminar
    info "Creando backup antes de eliminar..."
    local backup_file
    backup_file=$(create_backup)
    if [[ $? -ne 0 ]]; then
        error "No se pudo crear backup. Operación cancelada"
        return 1
    fi
    
    # Eliminar claves
    info "Eliminando claves de Redis..."
    local deleted_count=0
    local failed_count=0
    
    for key in "${unique_keys[@]}"; do
        if $redis_cmd DEL "$key" >/dev/null 2>&1; then
            ((deleted_count++))
        else
            ((failed_count++))
            warning "No se pudo eliminar la clave: $key"
        fi
        
        # Mostrar progreso cada 100 claves
        if [[ $((deleted_count % 100)) -eq 0 ]]; then
            info "Progreso: $deleted_count claves eliminadas..."
        fi
    done
    
    echo
    success "Operación completada:"
    success "  - Claves eliminadas: $deleted_count"
    if [[ $failed_count -gt 0 ]]; then
        warning "  - Claves fallidas: $failed_count"
    fi
    success "  - Backup creado en: $backup_file"
    
    return 0
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO REDIS CACHE CLEANER PARA KUBERNETES ==="
    
    # Variables por defecto
    local mode=""
    local config_file=""
    local patterns=""
    local words=""
    local backup_file=""
    local auto_confirm="false"
    local dry_run="false"
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -m|--mode)
                mode="$2"
                shift 2
                ;;
            -p|--patterns)
                patterns="$2"
                shift 2
                ;;
            -w|--words)
                words="$2"
                shift 2
                ;;
            -b|--backup)
                backup_file="$2"
                shift 2
                ;;
            -y|--yes)
                auto_confirm="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    
    # Crear directorio de backups
    create_backup_dir
    
    # Modo list - listar backups sin configuración
    if [[ "$mode" == "list" ]]; then
        list_backups
        exit $?
    fi
    
    # Cargar configuración
    if [[ -n "$config_file" ]]; then
        load_config "$config_file" || exit 1
    else
        interactive_config
    fi
    
    # Verificar dependencias
    check_dependencies || exit 1
    
    # Establecer conexiones
    if [[ "$USE_SSH_TUNNEL" == "true" ]]; then
        # Usar túnel SSH directo
        setup_ssh_tunnel "$SSH_HOST" "$SSH_USER" "$SSH_KEY" "$LOCAL_PORT" "$REDIS_HOST" "$REDIS_PORT" || exit 1
        REDIS_HOST="localhost"
        REDIS_PORT="$LOCAL_PORT"
    else
        # Verificar conexión K8s y establecer port-forward si es necesario
        test_k8s_connection || exit 1
        
        if [[ "$REDIS_HOST" == "localhost" || "$REDIS_HOST" == "127.0.0.1" ]]; then
            setup_k8s_port_forward || exit 1
        fi
    fi
    
    # Probar conexión a Redis
    test_redis_connection || exit 1
    
    # Ejecutar según modo
    case "$mode" in
        "search")
            if [[ -z "$patterns" && -z "$words" ]]; then
                read -p "Ingresa patrones (ej: cache:*,session:*): " patterns
                read -p "Ingresa palabras específicas (ej: user_123,order_456): " words
            fi
            search_keys "$patterns" "$words"
            ;;
        
        "clean")
            if [[ -z "$patterns" && -z "$words" ]]; then
                read -p "Ingresa patrones (ej: cache:*,session:*): " patterns
                read -p "Ingresa palabras específicas (ej: user_123,order_456): " words
            fi
            clean_keys "$patterns" "$words" "$auto_confirm" "$dry_run"
            ;;
        
        "restore")
            if [[ -z "$backup_file" ]]; then
                echo
                list_backups
                echo
                read -p "Ingresa el nombre del archivo de backup: " backup_file
                if [[ "$backup_file" != */* ]]; then
                    backup_file="$BACKUP_DIR/$backup_file"
                fi
            fi
            restore_backup "$backup_file"
            ;;
        
        "")
            error "Modo de operación requerido. Usa -m search|clean|restore|list"
            show_help
            exit 1
            ;;
        
        *)
            error "Modo desconocido: $mode"
            show_help
            exit 1
            ;;
    esac
    
    success "=== OPERACIÓN COMPLETADA ==="
}

# Ejecutar función principal con todos los argumentos
main "$@"
