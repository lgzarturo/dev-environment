# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    fzf
    brew
    docker
    docker-compose
    node
    npm
    python
    pip
    vscode
    history-substring-search
    colored-man-pages
    extract
    z
    kubectl
    kube-ps1
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

export LANG=en_US.UTF-8

# User configuration
export EDITOR='nvim'
export VISUAL='nvim'

# Aliases
alias ll='eza -la --icons --git'
alias la='eza -la --icons --git'
alias ls='eza --icons'
alias cat='bat'
alias f='fd'
alias grep='rg'
alias vim='nvim'
alias vi='nvim'

# History configuration
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_BEEP
setopt APPEND_HISTORY

# FZF configuration
export FZF_DEFAULT_COMMAND='fd --type file'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# NVM configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Python user base
export PATH="$HOME/.local/bin:$PATH"

# Custom functions
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Load Powerlevel10k configuration if available
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Auto-update Oh My Zsh every 30 days
export UPDATE_ZSH_DAYS=30

# SSH Tunnel Functions
tunnel-stage() {
    echo "🔗 Iniciando túnel a Stage..."
    /Users/lgzarturo/.devenv/tunnels/stage-tunnel.sh
}

tunnel-prod() {
    echo "🔗 Iniciando túnel a Producción..."
    /Users/lgzarturo/.devenv/tunnels/prod-tunnel.sh
}

tunnel-ows() {
    echo "🔗 Iniciando túneles a OWS..."
    /Users/lgzarturo/.devenv/tunnels/ows-tunnels.sh
}

tunnel-ows-validate() {
    echo "🔍 Validando conectividad a OWS..."
    /Users/lgzarturo/.devenv/tunnels/ows-connection-validate.sh
}

tunnel-ows-stop() {
    echo "🛑 Deteniendo túneles a OWS..."
    /Users/lgzarturo/.devenv/tunnels/stop-ows-tunnels.sh
}

ows-verify() {
    echo "🔍 Verificando túneles SSH y conectividad a OWS..."
    /Users/lgzarturo/.devenv/tunnels/ows-verify.sh
}

kill-tunnels() {
    echo "🔪 Cerrando todos los túneles SSH..."
    pkill -f "ssh.*-L.*:6443" || echo "No hay túneles activos"
}

checklist-tracking() {
    echo "👌🏻 Generando checklist..."
    /Users/lgzarturo/.scripts/environment/checklist_tracking.sh "$1" "$2" "$3" "$4" "$5"
}

check-fonts() {
    echo "🔍 Verificando fuentes instaladas..."
    /Users/lgzarturo/.scripts/environment/check_fonts_installed.sh
}

install-fonts() {
    echo "⬇️ Instalando fuentes faltantes..."
    /Users/lgzarturo/.scripts/environment/install_missing_fonts.sh
}

svg2jpg() {
    if [[ -z "$1" ]]; then
        echo "Uso: svg2jpg <directorio>"
        return 1
    fi
    if [[ "$2" == "--force-16-9" ]]; then
        echo "🔄 Convirtiendo archivos del directorio $1 a JPG"
        /Users/lgzarturo/.scripts/environment/svg2jpg4k.sh "$1" --force-16-9
    else
        /Users/lgzarturo/.scripts/environment/svg2jpg4k.sh "$1"
    fi
}

jpgoptim() {
    if [[ -z "$1" ]]; then
        echo "Uso: jpgoptim <directorio>"
        return 1
    fi
    /Users/lgzarturo/.scripts/environment/optimize_jpg_images.sh "$1"
}

# =============================================================================
# KUBERNETES CONFIGURATION
# =============================================================================

# Load kubectl aliases
if [ -f ~/.kubectl_aliases ]; then
    source ~/.kubectl_aliases
fi

# Kubernetes aliases
alias k='kubectl'
alias kgs='kubectl get pods'
alias kgp='kubectl get pods -n hotel-rates'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
alias kg='kubectl get'
alias kgpo='kubectl get pods'
alias klo='kubectl logs -f'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias kdp='kubectl describe pods'
alias krp='kubectl rollout restart deployment'
alias kar='kubectl scale --replicas=3 deployment'
alias kdr='kubectl scale --replicas=1 deployment'

source <(fzf --zsh)
source <(kubectl completion zsh)
PROMPT='$(kube_ps1)'\$PROMPT

# Funciones interactivas para kubectl usando fzf
klogsp() {
  kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}' \
  | fzf --preview="kubectl logs {2} -n {1} --all-containers" \
  --preview-window=up:60%
}

kdpod() {
  local ns pod
  read -r ns pod <<< "$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}' | fzf)"
  kubectl exec -n "$ns" -it "$pod" bash
}

# Context switching
alias k-stage='export KUBECONFIG=~/.kube/config-stage'
alias k-prod='export KUBECONFIG=~/.kube/config-prod'

# Kubernetes functions
kpods() {
    if [[ "$1" == "prod" ]]; then
        kubectl get pods -n hotels-rates
    else
        kubectl get pods
    fi
}

klogs() {
    local env="$1"
    local app="$2"

    if [[ "$env" == "prod" ]]; then
        stern "$app" -n hotels-rates
    else
        stern "$app"
    fi
}

kshell() {
    local pod="$1"
    local env="$2"

    if [[ "$env" == "prod" ]]; then
        kubectl exec -it "$pod" -n hotels-rates -- /bin/bash
    else
        kubectl exec -it "$pod" -- /bin/bash
    fi
}

# Combined tunnel + kubectl functions
k-stage-connect() {
    echo "🔗 Conectando a Stage..."
    export KUBECONFIG=~/.kube/config-stage
    tunnel-stage &
    sleep 5
    kubectl get nodes
}

k-prod-connect() {
    echo "🔗 Conectando a Producción..."
    export KUBECONFIG=~/.kube/config-prod
    tunnel-prod &
    sleep 5
    kubectl get nodes
}

# =============================================================================
# STERN CONFIGURATION FOR LOGS
# =============================================================================

# Stern functions for different environments
logs-stage() {
    local app="$1"
    if [[ -z "$app" ]]; then
        echo "Uso: logs-stage <nombre-app>"
        echo "Ejemplo: logs-stage nginx"
        return 1
    fi

    echo "📋 Mostrando logs de $app en STAGE..."
    export KUBECONFIG=~/.kube/config-stage
    stern "$app" --tail=50 --color=always
}

logs-prod() {
    local app="$1"
    if [[ -z "$app" ]]; then
        echo "Uso: logs-prod <nombre-app>"
        echo "Ejemplo: logs-prod api"
        return 1
    fi

    echo "📋 Mostrando logs de $app en PRODUCCIÓN..."
    export KUBECONFIG=~/.kube/config-prod
    stern "$app" -n hotels-rates --tail=50 --color=always
}

logs-all() {
    local app="$1"
    if [[ -z "$app" ]]; then
        echo "Uso: logs-all <nombre-app>"
        echo "Ejemplo: logs-all frontend"
        return 1
    fi

    echo "📋 Mostrando logs de $app en AMBOS entornos..."

    # Stage en una ventana
    export KUBECONFIG=~/.kube/config-stage
    stern "$app" --tail=10 --color=always --prefix="[STAGE]" &
    local stage_pid=$!

    # Production en otra ventana
    export KUBECONFIG=~/.kube/config-prod
    stern "$app" -n hotels-rates --tail=10 --color=always --prefix="[PROD]" &
    local prod_pid=$!

    # Función para limpiar al salir
    cleanup_logs() {
        kill $stage_pid $prod_pid 2>/dev/null || true
        echo "🔴 Logs cerrados"
    }

    trap cleanup_logs EXIT
    wait
}

# Función para mostrar pods disponibles
list-apps() {
    local env="$1"

    case "$env" in
        "stage")
            echo "📱 Apps disponibles en STAGE:"
            export KUBECONFIG=~/.kube/config-stage
            kubectl get pods -o jsonpath='{range .items[*]}{.metadata.labels.app}{"\n"}{end}' | sort -u | grep -v '^$'
            ;;
        "prod")
            echo "📱 Apps disponibles en PRODUCCIÓN:"
            export KUBECONFIG=~/.kube/config-prod
            kubectl get pods -n hotels-rates -o jsonpath='{range .items[*]}{.metadata.labels.app}{"\n"}{end}' | sort -u | grep -v '^$'
            ;;
        *)
            echo "Uso: list-apps [stage|prod]"
            echo "Ejemplo: list-apps stage"
            ;;
    esac
}

# =============================================================================
# ADDITIONAL USEFUL ALIASES
# =============================================================================

# Git aliases
alias gs='git status'
alias ga='git add'
alias gaa='git add .'
alias gc='git commit -m'
alias gca='git commit -am'
alias gp='git push'
alias gpl='git pull'
alias gb='git branch'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gm='git merge'
alias glog='git log --oneline --graph --decorate --all'
alias gdiff='git diff'
alias gstash='git stash'
alias gpop='git stash pop'

# AWS aliases
alias aws-whoami='aws sts get-caller-identity'
alias ec2-list='aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]" --output table'
alias s3-list='aws s3 ls'
alias logs-aws='aws logs describe-log-groups --query "logGroups[*].logGroupName" --output table'

# System aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias ports='netstat -tuln'
alias myip='curl -s ifconfig.me'

# Development aliases
alias serve='python3 -m http.server 8000'
alias json='jq .'
alias yaml='yq .'
alias decode64='base64 -d'
alias encode64='base64'

# Docker aliases (si usas Docker)
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias dex='docker exec -it'
alias dlogs='docker logs'

# Kubernetes development helpers
alias kwatch='watch -n1 kubectl get pods'
alias ktop='kubectl top nodes && echo && kubectl top pods'
alias kevents='kubectl get events --sort-by=.metadata.creationTimestamp'

# Functions for development
mkcd() {
    mkdir -p "$1" && cd "$1"
}

extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xvjf "$1"    ;;
            *.tar.gz)    tar xvzf "$1"    ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xvf "$1"     ;;
            *.tbz2)      tar xvjf "$1"    ;;
            *.tgz)       tar xvzf "$1"    ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "No sé cómo extraer '$1'..." ;;
        esac
    else
        echo "'$1' no es un archivo válido"
    fi
}

# Show environment info
devenv-info() {
    echo "🔧 INFORMACIÓN DEL ENTORNO DE DESARROLLO"
    echo "========================================"
    echo
    echo "📍 Sistema: $(uname -s) $(uname -r)"
    echo "📍 Shell: $SHELL"
    echo "📍 Usuario: $(whoami)"
    echo "📍 Directorio: $(pwd)"
    echo
    echo "🐙 Git:"
    echo "   Usuario: $(git config --global user.name)"
    echo "   Email: $(git config --global user.email)"
    echo
    echo "☁️ AWS:"
    echo "   Región: ${AWS_REGION:-No configurada}"
    echo "   Usuario: $(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo 'No configurado')"
    echo
    echo "⚓ Kubernetes:"
    echo "   Context actual: $(kubectl config current-context 2>/dev/null || echo 'No configurado')"
    echo "   Namespace: $(kubectl config view --minify --output 'jsonpath={.contexts[0].context.namespace}' 2>/dev/null || echo 'default')"
    echo
    echo "🔧 Herramientas:"
    command -v kubectl >/dev/null && echo "   ✅ kubectl $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)"
    command -v stern >/dev/null && echo "   ✅ stern $(stern --version 2>/dev/null | cut -d' ' -f3)"
    command -v aws >/dev/null && echo "   ✅ aws-cli $(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"
    command -v git >/dev/null && echo "   ✅ git $(git --version | cut -d' ' -f3)"
    command -v jq >/dev/null && echo "   ✅ jq $(jq --version | tr -d '\"')"
    command -v yq >/dev/null && echo "   ✅ yq $(yq --version | tr -d '\"')"
    command -v docker >/dev/null && echo "   ✅ Docker $(docker --version | cut -d' ' -f3)"
    command -v node >/dev/null && echo "   ✅ Node.js $(node --version | tr -d 'v')"
    command -v npm >/dev/null && echo "   ✅ npm $(npm --version)"
}
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/lgzarturo/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
#

# Limpiar la pantalla al iniciar
clear

# Mostrar un mensaje de bienvenida
echo "¡Bienvenido, $(whoami)!"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

export PATH="/Library/TeX/texbin:$PATH"
