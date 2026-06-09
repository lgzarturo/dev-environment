#!/bin/zsh

# Dirección a la cual hacer ping (puedes cambiarla si lo prefieres)
PING_ADDRESS="8.8.8.8"

# Bandera para saber si la conexión estaba caída
CONNECTION_LOST=0

# Función para mostrar notificaciones en macOS
function notify() {
    local title=$1
    local message=$2
    osascript -e "display notification \"$message\" with title \"$title\""
}

# Bucle infinito para monitorear la conexión
while true; do
    # Realiza un ping con timeout de 5 segundos
    ping -c 1 -t 5 $PING_ADDRESS > /dev/null 2>&1
    
    # Verifica si el ping tuvo éxito
    if [ $? -eq 0 ]; then
        # Si la conexión se recuperó después de haber estado perdida
        if [ $CONNECTION_LOST -eq 1 ]; then
            notify "Conexión Restablecida" "La conexión a Internet ha regresado."
            CONNECTION_LOST=0
        fi
    else
        # Si la conexión se perdió y antes estaba bien
        if [ $CONNECTION_LOST -eq 0 ]; then
            notify "Conexión Perdida" "Se ha perdido la conexión a Internet."
            CONNECTION_LOST=1
        fi
    fi
    
    # Espera 10 segundos antes de hacer el siguiente ping
    sleep 10
done
