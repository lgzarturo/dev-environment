#!/usr/bin/env zsh
##? Conectarse a una imagen de Docker

if docker ps >/dev/null 2>&1; then
    container=$(docker ps | awk '{if (NR!=1) print $1 ": " $(NF)}' | fzf --height 40%)

    if [[ -n $container ]]; then
        container_id=$(echo "$container" | awk -F ': ' '{print $1}')
        docker exec -it "$container_id" /bin/bash || docker exec -it "$container_id" /bin/sh
    else
        echo "🤫 No has seleccionado un contenedor"
    fi
else
    echo "🧟‍♂️ El demonio de docker no se esta ejecutando"
fi
