#!/bin/bash

# Script de Optimización Ubuntu Mate para ThinkPad X280 en USB 3.1
# Versión: 1.0
# Descripción: Optimiza sistema, terminal, Docker, Ollama y Git para desarrollo profesional

set -e  # Salir si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Verificar si se ejecuta como root para ciertas operaciones
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        error "No ejecutes este script como root. Usará sudo cuando sea necesario."
        exit 1
    fi
}

# Función para hacer backup de archivos importantes
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sudo cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backup creado: ${file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Función principal de optimización del sistema
optimize_system() {
    log "=== INICIANDO OPTIMIZACIÓN DEL SISTEMA PARA USB ==="

    # 1. Actualizar sistema
    log "Actualizando sistema..."
    sudo apt update && sudo apt upgrade -y

    # 2. Instalar herramientas necesarias
    log "Instalando herramientas básicas..."
    sudo apt install -y curl wget git zsh htop neofetch tree fzf ripgrep fd-find bat build-essential software-properties-common apt-transport-https ca-certificates gnupg lsb-release hdparm

    # 3. Backup del fstab
    backup_file "/etc/fstab"

    # 4. Configurar fstab para optimización USB
    log "Configurando fstab para optimización USB..."

    # Obtener el dispositivo root
    ROOT_DEVICE=$(df / | tail -1 | awk '{print $1}')
    ROOT_UUID=$(sudo blkid -s UUID -o value $ROOT_DEVICE)

    # Crear nuevo fstab optimizado
    sudo tee /etc/fstab > /dev/null <<EOF
# Fstab optimizado para ejecución desde USB
UUID=$ROOT_UUID / ext4 defaults,noatime,nodiratime,commit=600 0 1
tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0
tmpfs /var/log tmpfs defaults,noatime,mode=0755 0 0
tmpfs /var/tmp tmpfs defaults,noatime,mode=1777 0 0
EOF

    # 5. Configurar swappiness
    log "Configurando swappiness para priorizar RAM..."
    echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
    echo "vm.dirty_background_ratio=15" | sudo tee -a /etc/sysctl.conf
    echo "vm.dirty_ratio=20" | sudo tee -a /etc/sysctl.conf

    # 6. Deshabilitar swap si existe
    log "Deshabilitando swap..."
    sudo swapoff -a 2>/dev/null || true

    # 7. Configurar scheduler de I/O
    log "Configurando scheduler I/O para SSD/USB..."
    echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="deadline"' | sudo tee /etc/udev/rules.d/60-scheduler.rules

    # 8. Deshabilitar servicios innecesarios
    log "Deshabilitando servicios innecesarios..."
    SERVICES_TO_DISABLE=(
        "snapd"
        "snapd.socket"
        "bluetooth"
        "cups"
        "cups-browsed"
        "ModemManager"
    )

    for service in "${SERVICES_TO_DISABLE[@]}"; do
        sudo systemctl disable "$service" 2>/dev/null || warning "No se pudo deshabilitar $service"
    done

    log "Optimización del sistema completada."
}

# Función para instalar y configurar Oh My Zsh
setup_ohmyzsh() {
    log "=== CONFIGURANDO OH-MY-ZSH ==="

    # Cambiar shell a zsh
    if [[ "$SHELL" != *"zsh"* ]]; then
        log "Cambiando shell a zsh..."
        chsh -s $(which zsh)
    fi

    # Instalar Oh My Zsh si no existe
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log "Instalando Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Backup del .zshrc actual
    backup_file "$HOME/.zshrc"

    # Instalar plugins adicionales
    log "Instalando plugins adicionales..."

    # zsh-autosuggestions
    if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    fi

    # zsh-syntax-highlighting
    if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    fi

    # powerlevel10k theme
    if [[ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    fi

    # Crear .zshrc optimizado
    log "Creando .zshrc optimizado..."

    cat > "$HOME/.zshrc" << 'EOF'
# Oh My Zsh Configuration - Optimizado para desarrollo
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins para desarrollo
plugins=(
    git
    docker
    docker-compose
    kubectl
    helm
    terraform
    aws
    gcloud
    node
    npm
    yarn
    python
    pip
    virtualenv
    golang
    rust
    z
    fzf
    history
    history-substring-search
    command-not-found
    colored-man-pages
    colorize
    cp
    extract
    web-search
    jsontools
    encode64
    urltools
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Configuración de historial
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_VERIFY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

source $ZSH/oh-my-zsh.sh

# Variables de entorno
export EDITOR='nano'
export VISUAL='nano'
export PAGER='less'
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Path optimizado
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"

# Docker sin sudo
export DOCKER_HOST=unix:///var/run/docker.sock

# Go
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin"

# Node.js
export NODE_OPTIONS="--max-old-space-size=4096"

# Python
export PYTHONPATH="$HOME/.local/lib/python3.10/site-packages:$PYTHONPATH"

# Aliases útiles para desarrollo
alias ll='exa -la --icons --git'
alias ls='exa --icons'
alias tree='exa --tree --icons'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias ps='ps auxf'
alias mkdir='mkdir -pv'
alias h='history'
alias j='jobs -l'
alias path='echo -e ${PATH//:/\n}'
alias now='date +"%T"'
alias nowtime=now
alias nowdate='date +"%d-%m-%Y"'

# Git aliases avanzados
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gm='git merge'
alias gr='git rebase'
alias gf='git fetch'
alias glog='git log --oneline --graph --decorate --all'
alias gstash='git stash'
alias gunstash='git stash pop'

# Docker aliases
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs'
alias dstop='docker stop $(docker ps -q)'
alias drm='docker rm $(docker ps -aq)'
alias drmi='docker rmi $(docker images -q)'

# Sistema
alias reload='source ~/.zshrc'
alias update='sudo apt update && sudo apt upgrade'
alias install='sudo apt install'
alias search='apt search'
alias meminfo='free -m -l -t'
alias cpuinfo='lscpu'
alias diskinfo='df -h'
alias netinfo='netstat -tuln'

# Funciones útiles
extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

mkcd() {
    mkdir -p "$1" && cd "$1"
}

# FZF configuration
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# Configuración específica para desarrollo
if command -v code &> /dev/null; then
    alias c='code'
    alias code.='code .'
fi

# Autocompletado mejorado
autoload -U compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Configuración de powerlevel10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

    log "Oh My Zsh configurado correctamente."
}

# Función para configurar Docker sin sudo
setup_docker() {
    log "=== CONFIGURANDO DOCKER SIN SUDO ==="

    # Instalar Docker
    if ! command -v docker &> /dev/null; then
        log "Instalando Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
    fi

    # Agregar usuario al grupo docker
    log "Agregando usuario al grupo docker..."
    sudo usermod -aG docker $USER

    # Instalar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "Instalando Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi

    # Habilitar Docker service
    sudo systemctl enable docker
    sudo systemctl start docker

    log "Docker configurado para ejecutar sin sudo."
    warning "Necesitarás cerrar sesión y volver a iniciar para que los cambios surtan efecto."
}

# Función para configurar Ollama sin sudo
setup_ollama() {
    log "=== CONFIGURANDO OLLAMA SIN SUDO ==="

    # Instalar Ollama
    if ! command -v ollama &> /dev/null; then
        log "Instalando Ollama..."
        curl -fsSL https://ollama.ai/install.sh | sh
    fi

    # Crear grupo ollama si no existe
    if ! getent group ollama > /dev/null 2>&1; then
        sudo groupadd ollama
    fi

    # Agregar usuario al grupo ollama
    sudo usermod -aG ollama $USER

    # Configurar servicio de Ollama
    sudo tee /etc/systemd/system/ollama.service > /dev/null <<EOF
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="HOME=/usr/share/ollama"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=default.target
EOF

    # Crear usuario del sistema para ollama
    sudo useradd -r -s /bin/false -m -d /usr/share/ollama ollama 2>/dev/null || true

    # Habilitar servicio
    sudo systemctl daemon-reload
    sudo systemctl enable ollama
    sudo systemctl start ollama

    log "Ollama configurado correctamente."
}

# Función para configurar herramientas profesionales de Git
setup_git_tools() {
    log "=== CONFIGURANDO HERRAMIENTAS PROFESIONALES DE GIT ==="

    # Instalar herramientas Git avanzadas
    log "Instalando herramientas Git avanzadas..."
    sudo apt install -y git-flow git-extras tig hub gh

    # Instalar lazygit
    if ! command -v lazygit &> /dev/null; then
        log "Instalando lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin
        rm lazygit lazygit.tar.gz
    fi

    # Configurar Git globalmente (solicitar datos al usuario)
    log "Configurando Git globalmente..."

    read -p "Ingresa tu nombre completo para Git: " git_name
    read -p "Ingresa tu email para Git: " git_email

    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.editor nano
    git config --global core.autocrlf input
    git config --global color.ui auto

    # Configurar aliases Git avanzados
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.st status
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    git config --global alias.visual '!gitk'
    git config --global alias.tree 'log --graph --pretty=format:"%h %s" --all'
    git config --global alias.aa 'add -A'
    git config --global alias.cm 'commit -m'
    git config --global alias.cam 'commit -am'
    git config --global alias.ps 'push'
    git config --global alias.pl 'pull'
    git config --global alias.df 'diff'
    git config --global alias.lg 'log --oneline --graph --decorate --all'

    log "Herramientas Git configuradas correctamente."
}

# Función para limpiar y optimizar el sistema
cleanup_system() {
    log "=== LIMPIEZA Y OPTIMIZACIÓN FINAL ==="

    # Limpiar paquetes
    log "Limpiando paquetes innecesarios..."
    sudo apt autoremove -y
    sudo apt autoclean

    # Limpiar journald
    log "Limpiando logs del sistema..."
    sudo journalctl --vacuum-time=3d

    # Limpiar cache de thumbnails
    log "Limpiando cache de thumbnails..."
    rm -rf ~/.cache/thumbnails/*

    # Aplicar configuraciones
    sudo sysctl -p

    log "Limpieza completada."
}

# Función para mostrar información del sistema
show_system_info() {
    log "=== INFORMACIÓN DEL SISTEMA ==="

    echo -e "${BLUE}"
    neofetch
    echo -e "${NC}"

    info "Espacio en disco:"
    df -h / /tmp /var/log /var/tmp 2>/dev/null || df -h /

    info "Memoria:"
    free -h

    info "Swappiness actual: $(cat /proc/sys/vm/swappiness)"

    if command -v docker &> /dev/null; then
        info "Docker version: $(docker --version)"
    fi

    if command -v ollama &> /dev/null; then
        info "Ollama version: $(ollama --version 2>/dev/null || echo 'Ollama instalado')"
    fi

    info "Oh My Zsh plugins activos:"
    if [[ -f "$HOME/.zshrc" ]]; then
        grep "plugins=" "$HOME/.zshrc" | head -1
    fi
}

# Función principal
main() {
    check_sudo

    log "Iniciando optimización completa de Ubuntu Mate para ThinkPad X280 en USB 3.1"
    log "Este proceso puede tomar varios minutos..."

    echo -e "${YELLOW}"
    echo "¿Qué componentes deseas instalar/configurar?"
    echo "1) Optimización completa (recomendado)"
    echo "2) Solo optimización del sistema"
    echo "3) Solo Oh My Zsh"
    echo "4) Solo Docker"
    echo "5) Solo Ollama"
    echo "6) Solo herramientas Git"
    echo "7) Personalizado"
    echo -e "${NC}"

    read -p "Selecciona una opción (1-7): " choice

    case $choice in
        1)
            optimize_system
            setup_ohmyzsh
            setup_docker
            setup_ollama
            setup_git_tools
            cleanup_system
            ;;
        2)
            optimize_system
            cleanup_system
            ;;
        3)
            setup_ohmyzsh
            ;;
        4)
            setup_docker
            ;;
        5)
            setup_ollama
            ;;
        6)
            setup_git_tools
            ;;
        7)
            echo "Selecciona los componentes a instalar:"
            read -p "¿Optimizar sistema? (y/n): " opt_sys
            read -p "¿Configurar Oh My Zsh? (y/n): " opt_zsh
            read -p "¿Configurar Docker? (y/n): " opt_docker
            read -p "¿Configurar Ollama? (y/n): " opt_ollama
            read -p "¿Configurar Git? (y/n): " opt_git

            [[ "$opt_sys" == "y" ]] && optimize_system
            [[ "$opt_zsh" == "y" ]] && setup_ohmyzsh
            [[ "$opt_docker" == "y" ]] && setup_docker
            [[ "$opt_ollama" == "y" ]] && setup_ollama
            [[ "$opt_git" == "y" ]] && setup_git_tools

            cleanup_system
            ;;
        *)
            error "Opción inválida"
            exit 1
            ;;
    esac

    show_system_info

    log "=== OPTIMIZACIÓN COMPLETADA ==="
    warning "IMPORTANTE: Reinicia el sistema para aplicar todos los cambios."
    warning "Después del reinicio, ejecuta 'source ~/.zshrc' o abre una nueva terminal."

    if [[ "$choice" == "1" || "$opt_docker" == "y" || "$opt_ollama" == "y" ]]; then
        warning "Para usar Docker y Ollama sin sudo, cierra sesión y vuelve a iniciar."
    fi

    info "Script de optimización finalizado correctamente."
}

# Ejecutar función principal
main "$@"
