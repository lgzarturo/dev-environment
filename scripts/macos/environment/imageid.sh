#!/usr/bin/env zsh
##? Copiar el id de una imagen en Docker
#?? 1.0.0
##?
##? Require:
##?   kubectl, awk, fzf
##? Usage:
##?   imageid
#docs::eval "$@"

if docker >/dev/null 2>&1; then
    container=$(docker images | awk '{if (NR!=1) print $1 ": " $3 ": " $(NF)}' | fzf --height 40%)

    if [[ -n $container ]]; then
        container_id=$(echo $container | awk -F ': ' '{print $2}')
        echo $container_id | pbcopy
        echo "👍 Se ha copiado el id de la imagen al portapapeles -> $container_id"
    else
        echo "😳 No se ha seleccionado la imagen."
    fi
else
    echo "🤬 No esta corriendo el 😈 de docker."
fi
