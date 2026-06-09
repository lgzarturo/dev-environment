#!/bin/bash

# Script para recolectar registros DNS y generar un zone file
# Uso: ./dns_backup.sh dominio.com

# Verificar si se proporcionó un dominio como argumento
if [ $# -eq 0 ]; then
    echo "Error: Debe proporcionar un dominio como argumento."
    echo "Uso: \$0 dominio.com"
    exit 1
fi

DOMAIN=$1
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="dns_backup_${DOMAIN}_${TIMESTAMP}"
RECORD_TYPES=("A" "AAAA" "CNAME" "MX" "NS" "TXT" "SPF" "SRV" "PTR" "CAA" "DNSKEY" "DS" "NAPTR" "SSHFP")
ZONE_FILE="${BACKUP_DIR}/${DOMAIN}_zone_file.txt"
LOG_FILE="${BACKUP_DIR}/dns_backup.log"

# Crear directorio para zone files
mkdir -p "$BACKUP_DIR"

# Iniciar archivo de log
echo "Iniciando backup DNS para $DOMAIN en $(date)" > "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Función para generar registros
generate_records() {
    local type=$1
    local output_file="${BACKUP_DIR}/${DOMAIN}_${type}.txt"

    echo "Consultando registros $type para $DOMAIN..." | tee -a "$LOG_FILE"

    # Usar +noall +answer para obtener respuestas más detalladas
    dig +noall +answer "$DOMAIN" "$type" > "$output_file"

    # También consultar con www. para dominios comunes
    if [[ "$type" == "A" || "$type" == "AAAA" ]]; then
        dig +noall +answer "www.$DOMAIN" "$type" >> "$output_file"
    fi

    # Verificar si se obtuvieron resultados
    if [ -s "$output_file" ]; then
        echo "  ✓ Registros $type encontrados" | tee -a "$LOG_FILE"
    else
        echo "  ✗ No se encontraron registros $type" | tee -a "$LOG_FILE"
        # Agregar comentario al archivo vacío
        echo "; No se encontraron registros $type para $DOMAIN" > "$output_file"
    fi
}

# Obtener SOA record primero (importante para zone files)
echo "Obteniendo registro SOA..." | tee -a "$LOG_FILE"
dig +noall +answer "$DOMAIN" SOA > "${BACKUP_DIR}/${DOMAIN}_SOA.txt"

# Iterar sobre tipos de registros
for type in "${RECORD_TYPES[@]}"; do
    generate_records "$type"
done

# Consolidar en un zone file con formato adecuado
echo "; Zone file para $DOMAIN" > "$ZONE_FILE"
echo "; Generado el $(date)" >> "$ZONE_FILE"
echo "; ----------------------------------" >> "$ZONE_FILE"
echo "" >> "$ZONE_FILE"

# Primero agregar SOA (Start of Authority)
echo "; SOA Record" >> "$ZONE_FILE"
cat "${BACKUP_DIR}/${DOMAIN}_SOA.txt" >> "$ZONE_FILE"
echo "" >> "$ZONE_FILE"

# Luego agregar NS (Name Servers)
echo "; NS Records" >> "$ZONE_FILE"
cat "${BACKUP_DIR}/${DOMAIN}_NS.txt" >> "$ZONE_FILE"
echo "" >> "$ZONE_FILE"

# Agregar el resto de registros en orden lógico
for type in "A" "AAAA" "CNAME" "MX" "TXT" "SPF" "SRV" "PTR" "CAA" "DNSKEY" "DS" "NAPTR" "SSHFP"; do
    if [ -s "${BACKUP_DIR}/${DOMAIN}_${type}.txt" ]; then
        echo "; $type Records" >> "$ZONE_FILE"
        cat "${BACKUP_DIR}/${DOMAIN}_${type}.txt" >> "$ZONE_FILE"
        echo "" >> "$ZONE_FILE"
    fi
done

# Crear archivo comprimido con todos los resultados
tar -czf "${DOMAIN}_dns_backup_${TIMESTAMP}.tar.gz" "$BACKUP_DIR"

echo "----------------------------------------" >> "$LOG_FILE"
echo "Backup DNS completado para $DOMAIN en $(date)" >> "$LOG_FILE"
echo "Archivos generados en: $BACKUP_DIR" | tee -a "$LOG_FILE"
echo "Zone file principal: $ZONE_FILE" | tee -a "$LOG_FILE"
echo "Archivo comprimido: ${DOMAIN}_dns_backup_${TIMESTAMP}.tar.gz" | tee -a "$LOG_FILE"

# Mostrar resumen
echo ""
echo "=== Resumen de Backup DNS para $DOMAIN ==="
echo "Backup completado exitosamente."
echo "Directorio de backup: $BACKUP_DIR"
echo "Zone file generado: $ZONE_FILE"
echo "Archivo comprimido: ${DOMAIN}_dns_backup_${TIMESTAMP}.tar.gz"
echo "Para más detalles, consulte el archivo de log: $LOG_FILE"
