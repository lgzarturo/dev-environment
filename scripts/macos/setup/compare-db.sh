#!/bin/bash

# =============================================================================
# PostgreSQL Schema Sync Script
# Compara dos esquemas PostgreSQL y genera consultas aditivas
# Funciona en Windows (Git Bash/WSL), Linux y macOS
# =============================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/schema_sync_$(date +%Y%m%d_%H%M%S).log"
TEMP_DIR="${SCRIPT_DIR}/temp_$$"
SOURCE_TUNNEL_PID=""
TARGET_TUNNEL_PID=""

# Configuración por defecto
DEFAULT_SSH_KEY="${HOME}/.ssh/id_rsa"
DEFAULT_LOCAL_PORT_SOURCE=5433
DEFAULT_LOCAL_PORT_TARGET=5434

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

cleanup() {
    info "Limpiando recursos..."
    
    # Cerrar túneles SSH
    if [[ -n "$SOURCE_TUNNEL_PID" ]]; then
        kill "$SOURCE_TUNNEL_PID" 2>/dev/null || true
        info "Túnel fuente cerrado (PID: $SOURCE_TUNNEL_PID)"
    fi
    
    if [[ -n "$TARGET_TUNNEL_PID" ]]; then
        kill "$TARGET_TUNNEL_PID" 2>/dev/null || true
        info "Túnel destino cerrado (PID: $TARGET_TUNNEL_PID)"
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

OPCIONES:
    -h, --help              Muestra esta ayuda
    -c, --config FILE       Archivo de configuración (opcional)
    
MODOS DE EJECUCIÓN:
    Interactivo: Sin parámetros, guía paso a paso
    Configuración: Con archivo de configuración

EJEMPLO DE ARCHIVO DE CONFIGURACIÓN:
    SOURCE_TYPE=remote          # local, remote
    SOURCE_HOST=source.example.com
    SOURCE_PORT=5432
    SOURCE_DB=source_db
    SOURCE_USER=postgres
    SOURCE_SCHEMA=public
    SOURCE_SSH_HOST=bastion1.aws.com
    SOURCE_SSH_USER=ec2-user
    SOURCE_SSH_KEY=/path/to/key.pem
    
    TARGET_TYPE=remote          # local, remote
    TARGET_HOST=target.example.com
    TARGET_PORT=5432
    TARGET_DB=target_db
    TARGET_USER=postgres
    TARGET_SCHEMA=public
    TARGET_SSH_HOST=bastion2.aws.com
    TARGET_SSH_USER=ec2-user
    TARGET_SSH_KEY=/path/to/key.pem
    
    APPLY_TO_ALL_SCHEMAS=true   # true, false
    DRY_RUN=false              # true, false

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
    
    # Configuración de base de datos fuente
    echo
    info "=== CONFIGURACIÓN DE BASE DE DATOS FUENTE ==="
    read -p "Tipo de conexión fuente (local/remote): " SOURCE_TYPE
    
    if [[ "$SOURCE_TYPE" == "remote" ]]; then
        read -p "Host SSH (bastion): " SOURCE_SSH_HOST
        read -p "Usuario SSH: " SOURCE_SSH_USER
        read -p "Clave SSH (Enter para $DEFAULT_SSH_KEY): " SOURCE_SSH_KEY
        SOURCE_SSH_KEY="${SOURCE_SSH_KEY:-$DEFAULT_SSH_KEY}"
        read -p "Puerto local para túnel (Enter para $DEFAULT_LOCAL_PORT_SOURCE): " SOURCE_LOCAL_PORT
        SOURCE_LOCAL_PORT="${SOURCE_LOCAL_PORT:-$DEFAULT_LOCAL_PORT_SOURCE}"
    fi
    
    read -p "Host PostgreSQL fuente: " SOURCE_HOST
    read -p "Puerto PostgreSQL fuente (Enter para 5432): " SOURCE_PORT
    SOURCE_PORT="${SOURCE_PORT:-5432}"
    read -p "Base de datos fuente: " SOURCE_DB
    read -p "Usuario PostgreSQL fuente: " SOURCE_USER
    read -s -p "Contraseña PostgreSQL fuente: " SOURCE_PASS
    echo
    read -p "Esquema fuente (Enter para 'public'): " SOURCE_SCHEMA
    SOURCE_SCHEMA="${SOURCE_SCHEMA:-public}"
    
    # Configuración de base de datos destino
    echo
    info "=== CONFIGURACIÓN DE BASE DE DATOS DESTINO ==="
    read -p "Tipo de conexión destino (local/remote): " TARGET_TYPE
    
    if [[ "$TARGET_TYPE" == "remote" ]]; then
        read -p "Host SSH (bastion): " TARGET_SSH_HOST
        read -p "Usuario SSH: " TARGET_SSH_USER
        read -p "Clave SSH (Enter para $DEFAULT_SSH_KEY): " TARGET_SSH_KEY
        TARGET_SSH_KEY="${TARGET_SSH_KEY:-$DEFAULT_SSH_KEY}"
        read -p "Puerto local para túnel (Enter para $DEFAULT_LOCAL_PORT_TARGET): " TARGET_LOCAL_PORT
        TARGET_LOCAL_PORT="${TARGET_LOCAL_PORT:-$DEFAULT_LOCAL_PORT_TARGET}"
    fi
    
    read -p "Host PostgreSQL destino: " TARGET_HOST
    read -p "Puerto PostgreSQL destino (Enter para 5432): " TARGET_PORT
    TARGET_PORT="${TARGET_PORT:-5432}"
    read -p "Base de datos destino: " TARGET_DB
    read -p "Usuario PostgreSQL destino: " TARGET_USER
    read -s -p "Contraseña PostgreSQL destino: " TARGET_PASS
    echo
    read -p "Esquema destino (Enter para 'public'): " TARGET_SCHEMA
    TARGET_SCHEMA="${TARGET_SCHEMA:-public}"
    
    # Configuración adicional
    echo
    info "=== CONFIGURACIÓN ADICIONAL ==="
    read -p "¿Aplicar cambios a todos los esquemas de la BD destino? (y/n): " apply_all
    APPLY_TO_ALL_SCHEMAS=$([[ "$apply_all" =~ ^[Yy]$ ]] && echo "true" || echo "false")
    
    read -p "¿Ejecutar en modo prueba (dry-run)? (y/n): " dry_run
    DRY_RUN=$([[ "$dry_run" =~ ^[Yy]$ ]] && echo "true" || echo "false")
}

# =============================================================================
# FUNCIONES DE CONECTIVIDAD
# =============================================================================

check_dependencies() {
    local deps=("psql" "ssh")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Dependencias faltantes: ${missing[*]}"
        error "Instala: sudo apt-get install postgresql-client openssh-client (Ubuntu/Debian)"
        error "O: brew install postgresql openssh (macOS)"
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
    local tunnel_name="$7"
    
    info "Estableciendo túnel SSH ($tunnel_name): localhost:$local_port -> $remote_host:$remote_port"
    
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
        log "Túnel SSH establecido ($tunnel_name) - PID: $tunnel_pid"
        echo "$tunnel_pid"
        return 0
    else
        error "No se pudo establecer el túnel SSH ($tunnel_name)"
        return 1
    fi
}

test_db_connection() {
    local host="$1"
    local port="$2"
    local db="$3"
    local user="$4"
    local pass="$5"
    local conn_name="$6"
    
    info "Probando conexión a base de datos ($conn_name)..."
    
    export PGPASSWORD="$pass"
    if psql -h "$host" -p "$port" -d "$db" -U "$user" -c "\q" &>/dev/null; then
        log "Conexión exitosa a base de datos ($conn_name)"
        return 0
    else
        error "No se pudo conectar a la base de datos ($conn_name)"
        return 1
    fi
}

# =============================================================================
# FUNCIONES DE COMPARACIÓN DE ESQUEMAS
# =============================================================================

create_temp_dir() {
    mkdir -p "$TEMP_DIR"
    log "Directorio temporal creado: $TEMP_DIR"
}

get_schema_structure() {
    local host="$1"
    local port="$2"
    local db="$3"
    local user="$4"
    local pass="$5"
    local schema="$6"
    local output_file="$7"
    
    export PGPASSWORD="$pass"
    
    info "Extrayendo estructura del esquema: $schema"
    
    # Query para obtener estructura completa del esquema
    cat > "${TEMP_DIR}/schema_query.sql" << 'EOF'
-- Obtener información de tablas y columnas
WITH table_columns AS (
    SELECT 
        t.table_name,
        c.column_name,
        c.ordinal_position,
        c.data_type,
        c.character_maximum_length,
        c.numeric_precision,
        c.numeric_scale,
        c.is_nullable,
        c.column_default,
        CASE 
            WHEN pk.column_name IS NOT NULL THEN 'PRIMARY KEY'
            ELSE ''
        END as constraint_type
    FROM information_schema.tables t
    LEFT JOIN information_schema.columns c ON t.table_name = c.table_name AND t.table_schema = c.table_schema
    LEFT JOIN (
        SELECT ku.table_name, ku.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage ku ON tc.constraint_name = ku.constraint_name
        WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_schema = $1
    ) pk ON c.table_name = pk.table_name AND c.column_name = pk.column_name
    WHERE t.table_schema = $1 AND t.table_type = 'BASE TABLE'
    ORDER BY t.table_name, c.ordinal_position
),
-- Obtener índices
table_indexes AS (
    SELECT 
        i.tablename as table_name,
        i.indexname as index_name,
        pg_get_indexdef(idx.indexrelid) as index_definition
    FROM pg_indexes i
    JOIN pg_class idx ON idx.relname = i.indexname
    JOIN pg_namespace n ON n.oid = idx.relnamespace
    WHERE n.nspname = $1
    AND i.indexname NOT LIKE '%_pkey'
),
-- Obtener foreign keys
foreign_keys AS (
    SELECT
        tc.table_name,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = $1
)
-- Resultado final combinado
SELECT 'TABLE' as object_type, table_name, column_name, ordinal_position, data_type, 
       character_maximum_length, numeric_precision, numeric_scale, is_nullable, 
       column_default, constraint_type, null as index_definition, null as foreign_table, null as foreign_column
FROM table_columns
UNION ALL
SELECT 'INDEX' as object_type, table_name, null, null, null, null, null, null, null, null, null, index_definition, null, null
FROM table_indexes
UNION ALL
SELECT 'FOREIGN_KEY' as object_type, table_name, column_name, null, null, null, null, null, null, null, null, null, foreign_table_name, foreign_column_name
FROM foreign_keys
ORDER BY object_type, table_name, ordinal_position;
EOF

    psql -h "$host" -p "$port" -d "$db" -U "$user" \
         -f "${TEMP_DIR}/schema_query.sql" \
         -v schema="$schema" \
         -t -A -F'|' > "$output_file"
    
    if [[ $? -eq 0 ]]; then
        log "Estructura del esquema extraída correctamente"
    else
        error "Error al extraer la estructura del esquema"
        return 1
    fi
}

compare_schemas() {
    local source_file="$1"
    local target_file="$2"
    local diff_file="$3"
    
    info "Comparando esquemas..."
    
    # Crear archivo de diferencias
    cat > "$diff_file" << 'EOF'
-- ============================================================================
-- SCRIPT DE MIGRACIÓN ADITIVA
-- Generado automáticamente
-- ============================================================================

EOF
    
    # Procesar diferencias usando awk
    awk -F'|' '
    BEGIN {
        print "-- Analizando diferencias entre esquemas..." >> "'$diff_file'"
    }
    
    # Cargar esquema destino
    FILENAME == "'$target_file'" {
        if ($1 == "TABLE") {
            target_tables[$2] = 1
            target_columns[$2 "." $3] = $4 "|" $5 "|" $6 "|" $7 "|" $8 "|" $9 "|" $10 "|" $11
        }
    }
    
    # Comparar con esquema fuente
    FILENAME == "'$source_file'" {
        if ($1 == "TABLE") {
            table = $2
            column = $3
            
            # Tabla nueva
            if (!(table in target_tables)) {
                if (!(table in new_tables)) {
                    print "\n-- Nueva tabla: " table >> "'$diff_file'"
                    new_tables[table] = 1
                }
            }
            # Columna nueva en tabla existente
            else if (!(table "." column in target_columns)) {
                if (!(table in new_columns)) {
                    print "\n-- Nuevas columnas para tabla: " table >> "'$diff_file'"
                    new_columns[table] = 1
                }
            }
        }
    }
    ' "$target_file" "$source_file"
    
    log "Comparación de esquemas completada"
}

generate_migration_sql() {
    local source_file="$1"
    local target_file="$2"
    local migration_file="$3"
    
    info "Generando script de migración SQL..."
    
    # Script Python para generar SQL más robusto
    cat > "${TEMP_DIR}/generate_sql.py" << 'EOF'
#!/usr/bin/env python3
import sys
import re

def parse_schema_file(filename):
    tables = {}
    indexes = {}
    foreign_keys = {}
    
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
                
            parts = line.split('|')
            if len(parts) < 4:
                continue
                
            obj_type = parts[0]
            
            if obj_type == 'TABLE':
                table_name = parts[1]
                column_name = parts[2]
                
                if table_name not in tables:
                    tables[table_name] = {}
                
                if column_name and column_name != 'null':
                    tables[table_name][column_name] = {
                        'position': parts[3] if parts[3] != 'null' else None,
                        'data_type': parts[4] if parts[4] != 'null' else 'text',
                        'max_length': parts[5] if parts[5] != 'null' else None,
                        'precision': parts[6] if parts[6] != 'null' else None,
                        'scale': parts[7] if parts[7] != 'null' else None,
                        'nullable': parts[8] if parts[8] != 'null' else 'YES',
                        'default': parts[9] if parts[9] != 'null' else None,
                        'constraint': parts[10] if parts[10] != 'null' else None
                    }
            
            elif obj_type == 'INDEX':
                table_name = parts[1]
                if table_name not in indexes:
                    indexes[table_name] = []
                if len(parts) > 11 and parts[11] != 'null':
                    indexes[table_name].append(parts[11])
            
            elif obj_type == 'FOREIGN_KEY':
                table_name = parts[1]
                if table_name not in foreign_keys:
                    foreign_keys[table_name] = []
                if len(parts) > 13:
                    foreign_keys[table_name].append({
                        'column': parts[2],
                        'ref_table': parts[12],
                        'ref_column': parts[13]
                    })
    
    return tables, indexes, foreign_keys

def format_column_definition(column_name, column_info):
    data_type = column_info['data_type']
    
    # Formatear tipo de datos
    if data_type in ['character varying', 'varchar'] and column_info['max_length']:
        data_type = f"VARCHAR({column_info['max_length']})"
    elif data_type == 'character' and column_info['max_length']:
        data_type = f"CHAR({column_info['max_length']})"
    elif data_type == 'numeric' and column_info['precision']:
        if column_info['scale']:
            data_type = f"NUMERIC({column_info['precision']},{column_info['scale']})"
        else:
            data_type = f"NUMERIC({column_info['precision']})"
    else:
        data_type = data_type.upper()
    
    # Construir definición
    definition = f"{column_name} {data_type}"
    
    # Nullable
    if column_info['nullable'] == 'NO':
        definition += " NOT NULL"
    
    # Default
    if column_info['default']:
        definition += f" DEFAULT {column_info['default']}"
    
    # Primary key
    if column_info['constraint'] == 'PRIMARY KEY':
        definition += " PRIMARY KEY"
    
    return definition

def generate_migration(source_file, target_file, output_file):
    source_tables, source_indexes, source_fks = parse_schema_file(source_file)
    target_tables, target_indexes, target_fks = parse_schema_file(target_file)
    
    with open(output_file, 'w') as f:
        f.write("-- ============================================================================\n")
        f.write("-- SCRIPT DE MIGRACIÓN ADITIVA AUTOMÁTICA\n")
        f.write(f"-- Generado: {sys.argv[0]}\n")
        f.write("-- ============================================================================\n\n")
        
        f.write("BEGIN;\n\n")
        
        # Nuevas tablas
        new_tables = set(source_tables.keys()) - set(target_tables.keys())
        if new_tables:
            f.write("-- ============================================================================\n")
            f.write("-- CREACIÓN DE NUEVAS TABLAS\n")
            f.write("-- ============================================================================\n\n")
            
            for table_name in sorted(new_tables):
                f.write(f"-- Crear tabla: {table_name}\n")
                f.write(f"CREATE TABLE IF NOT EXISTS {table_name} (\n")
                
                columns = []
                for col_name, col_info in sorted(source_tables[table_name].items(), 
                                               key=lambda x: int(x[1]['position'] or 0)):
                    columns.append(f"    {format_column_definition(col_name, col_info)}")
                
                f.write(",\n".join(columns))
                f.write("\n);\n\n")
        
        # Nuevas columnas
        f.write("-- ============================================================================\n")
        f.write("-- ADICIÓN DE NUEVAS COLUMNAS\n")
        f.write("-- ============================================================================\n\n")
        
        for table_name in source_tables:
            if table_name in target_tables:
                source_cols = set(source_tables[table_name].keys())
                target_cols = set(target_tables[table_name].keys())
                new_cols = source_cols - target_cols
                
                if new_cols:
                    f.write(f"-- Nuevas columnas para tabla: {table_name}\n")
                    for col_name in sorted(new_cols):
                        col_info = source_tables[table_name][col_name]
                        f.write(f"ALTER TABLE {table_name} ADD COLUMN IF NOT EXISTS ")
                        f.write(f"{format_column_definition(col_name, col_info)};\n")
                    f.write("\n")
        
        # Nuevos índices
        f.write("-- ============================================================================\n")
        f.write("-- CREACIÓN DE NUEVOS ÍNDICES\n")
        f.write("-- ============================================================================\n\n")
        
        for table_name in source_indexes:
            if table_name in new_tables or table_name in target_tables:
                for index_def in source_indexes[table_name]:
                    # Modificar para usar IF NOT EXISTS
                    index_def_safe = index_def.replace("CREATE INDEX", "CREATE INDEX IF NOT EXISTS")
                    f.write(f"{index_def_safe};\n")
        
        f.write("\nCOMMIT;\n")
        f.write("\n-- Migración completada\n")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Uso: python3 generate_sql.py <source_file> <target_file> <output_file>")
        sys.exit(1)
    
    generate_migration(sys.argv[1], sys.argv[2], sys.argv[3])

EOF

    python3 "${TEMP_DIR}/generate_sql.py" "$source_file" "$target_file" "$migration_file"
    
    if [[ $? -eq 0 ]]; then
        log "Script de migración SQL generado: $migration_file"
    else
        error "Error al generar el script de migración SQL"
        return 1
    fi
}

# =============================================================================
# FUNCIONES DE EJECUCIÓN
# =============================================================================

get_all_schemas() {
    local host="$1"
    local port="$2"
    local db="$3"
    local user="$4"
    local pass="$5"
    
    export PGPASSWORD="$pass"
    psql -h "$host" -p "$port" -d "$db" -U "$user" -t -c \
        "SELECT schema_name FROM information_schema.schemata 
         WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast') 
         ORDER BY schema_name;" | grep -v '^$' | sed 's/^ *//'
}

execute_migration() {
    local host="$1"
    local port="$2"
    local db="$3"
    local user="$4"
    local pass="$5"
    local schema="$6"
    local migration_file="$7"
    local dry_run="$8"
    
    export PGPASSWORD="$pass"
    
    if [[ "$dry_run" == "true" ]]; then
        warning "MODO PRUEBA: No se ejecutarán los cambios en el esquema $schema"
        info "Contenido del script para $schema:"
        echo "----------------------------------------"
        cat "$migration_file"
        echo "----------------------------------------"
        return 0
    fi
    
    info "Ejecutando migración en esquema: $schema"
    
    # Modificar el script para usar el esquema específico
    local schema_migration_file="${TEMP_DIR}/migration_${schema}.sql"
    sed "s/CREATE TABLE IF NOT EXISTS /CREATE TABLE IF NOT EXISTS ${schema}./g; 
         s/ALTER TABLE /ALTER TABLE ${schema}./g;
         s/CREATE INDEX IF NOT EXISTS /CREATE INDEX IF NOT EXISTS /g" \
         "$migration_file" > "$schema_migration_file"
    
    # Agregar SET search_path al inicio
    sed -i "1i SET search_path TO ${schema}, public;" "$schema_migration_file"
    
    # Ejecutar migración
    if psql -h "$host" -p "$port" -d "$db" -U "$user" -f "$schema_migration_file"; then
        log "Migración ejecutada correctamente en esquema: $schema"
    else
        error "Error al ejecutar migración en esquema: $schema"
        return 1
    fi
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    log "=== INICIANDO SCRIPT DE SINCRONIZACIÓN DE ESQUEMAS POSTGRESQL ==="
    
    # Crear directorio temporal
    create_temp_dir
    
    # Verificar dependencias
    check_dependencies || exit 1
    
    # Procesar argumentos
    local config_file=""
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
            *)
                error "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Cargar configuración
    if [[ -n "$config_file" ]]; then
        load_config "$config_file" || exit 1
    else
        interactive_config
    fi
    
    # Establecer túneles SSH si es necesario
    if [[ "$SOURCE_TYPE" == "remote" ]]; then
        SOURCE_TUNNEL_PID=$(setup_ssh_tunnel "$SOURCE_SSH_HOST" "$SOURCE_SSH_USER" "$SOURCE_SSH_KEY" \
                                            "$SOURCE_LOCAL_PORT" "$SOURCE_HOST" "$SOURCE_PORT" "fuente")
        if [[ $? -ne 0 ]]; then
            error "No se pudo establecer túnel SSH para base de datos fuente"
            exit 1
        fi
        SOURCE_CONN_HOST="localhost"
        SOURCE_CONN_PORT="$SOURCE_LOCAL_PORT"
        sleep 3  # Esperar a que el túnel se establezca
    else
        SOURCE_CONN_HOST="$SOURCE_HOST"
        SOURCE_CONN_PORT="$SOURCE_PORT"
    fi
    
    if [[ "$TARGET_TYPE" == "remote" ]]; then
        TARGET_TUNNEL_PID=$(setup_ssh_tunnel "$TARGET_SSH_HOST" "$TARGET_SSH_USER" "$TARGET_SSH_KEY" \
                                            "$TARGET_LOCAL_PORT" "$TARGET_HOST" "$TARGET_PORT" "destino")
        if [[ $? -ne 0 ]]; then
            error "No se pudo establecer túnel SSH para base de datos destino"
            exit 1
        fi
        TARGET_CONN_HOST="localhost"
        TARGET_CONN_PORT="$TARGET_LOCAL_PORT"
        sleep 3  # Esperar a que el túnel se establezca
    else
        TARGET_CONN_HOST="$TARGET_HOST"
        TARGET_CONN_PORT="$TARGET_PORT"
    fi
    
    # Probar conexiones
    test_db_connection "$SOURCE_CONN_HOST" "$SOURCE_CONN_PORT" "$SOURCE_DB" \
                      "$SOURCE_USER" "$SOURCE_PASS" "fuente" || exit 1
    
    test_db_connection "$TARGET_CONN_HOST" "$TARGET_CONN_PORT" "$TARGET_DB" \
                      "$TARGET_USER" "$TARGET_PASS" "destino" || exit 1
    
    # Extraer estructuras de esquemas
    local source_schema_file="${TEMP_DIR}/source_schema.txt"
    local target_schema_file="${TEMP_DIR}/target_schema.txt"
    
    get_schema_structure "$SOURCE_CONN_HOST" "$SOURCE_CONN_PORT" "$SOURCE_DB" \
                        "$SOURCE_USER" "$SOURCE_PASS" "$SOURCE_SCHEMA" \
                        "$source_schema_file" || exit 1
    
    get_schema_structure "$TARGET_CONN_HOST" "$TARGET_CONN_PORT" "$TARGET_DB" \
                        "$TARGET_USER" "$TARGET_PASS" "$TARGET_SCHEMA" \
                        "$target_schema_file" || exit 1
    
    # Generar script de migración
    local migration_file="${TEMP_DIR}/migration.sql"
    generate_migration_sql "$source_schema_file" "$target_schema_file" "$migration_file" || exit 1
    
    # Verificar si hay cambios
    if [[ ! -s "$migration_file" ]] || ! grep -q "ALTER TABLE\|CREATE TABLE" "$migration_file"; then
        log "No se encontraron diferencias entre los esquemas. No hay cambios que aplicar."
        exit 0
    fi
    
    # Mostrar resumen de cambios
    info "=== RESUMEN DE CAMBIOS DETECTADOS ==="
    grep -E "^-- (Crear tabla|Nuevas columnas)" "$migration_file" | sed 's/^-- /- /'
    
    # Ejecutar migración
    if [[ "$APPLY_TO_ALL_SCHEMAS" == "true" ]]; then
        info "Obteniendo lista de todos los esquemas en la base de datos destino..."
        local all_schemas=$(get_all_schemas "$TARGET_CONN_HOST" "$TARGET_CONN_PORT" "$TARGET_DB" \
                                          "$TARGET_USER" "$TARGET_PASS")
        
        info "Esquemas encontrados:"
        echo "$all_schemas" | sed 's/^/  - /'
        
        for schema in $all_schemas; do
            execute_migration "$TARGET_CONN_HOST" "$TARGET_CONN_PORT" "$TARGET_DB" \
                            "$TARGET_USER" "$TARGET_PASS" "$schema" \
                            "$migration_file" "$DRY_RUN"
        done
    else
        execute_migration "$TARGET_CONN_HOST" "$TARGET_CONN_PORT" "$TARGET_DB" \
                        "$TARGET_USER" "$TARGET_PASS" "$TARGET_SCHEMA" \
                        "$migration_file" "$DRY_RUN"
    fi
    
    # Copiar archivos importantes al directorio actual
    cp "$migration_file" "${SCRIPT_DIR}/migration_$(date +%Y%m%d_%H%M%S).sql"
    cp "$LOG_FILE" "${SCRIPT_DIR}/"
    
    log "=== PROCESO COMPLETADO EXITOSAMENTE ==="
    log "Archivos generados:"
    log "  - Log: $LOG_FILE"
    log "  - Script de migración: ${SCRIPT_DIR}/migration_$(date +%Y%m%d_%H%M%S).sql"
}

# Ejecutar función principal con todos los argumentos
main "$@"
