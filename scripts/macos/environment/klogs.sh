#!/usr/bin/env zsh
##? Conectarse al log de kubernetes
#?? 1.0.0
##?
##? Require:
##?   kubectl, awk, fzf
##? Usage:
##?   logs
#docs::eval "$@"

if kubectl >/dev/null 2>&1; then
    pod_container=$(kubectl get pods | awk '{if (NR!=1) print $1 ": " $(NF)}' | fzf --height 40%)

    if [[ -n $pod_container ]]; then
        pod_container_id=$(echo $pod_container | awk -F ': ' '{print $1}')
        kubectl logs -f $pod_container_id
    else
        echo "😳 No se ha seleccionado el pod."
    fi
else
    echo "🤬 No esta corriendo el 😈 de kubectl."
fi
