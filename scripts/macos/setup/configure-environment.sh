#!/bin/bash

# =============================================================================
# Development Environment Setup Script
# Configura un entorno completo para desarrollo con GitHub, AWS y Kubernetes
# Soporta Linux y macOS con configuración interactiva paso a paso
# =============================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
CONFIG_DIR="${HOME}/.devenv"
BACKUP_DIR="${CONFIG_DIR}/backups"

# Detectar OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    DISTRO="macOS"
else
    OS="unknown"
    DISTRO="Unknown"
fi

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

section() {
    echo
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo
}

explain() {
    echo
    echo -e "${YELLOW}💡 EXPLICACIÓN:${NC} $1"
    echo
}

ask_continue() {
    echo
    read -p "¿Deseas continuar con este paso? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Paso omitido por el usuario"
        return 1
    fi
    return 0
}

create_dirs() {
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    log "Directorios de configuración creados"
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_name="$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$BACKUP_DIR/$backup_name"
        info "Backup creado: $backup_name"
    fi
}

# =============================================================================
# FUNCIONES DE INSTALACIÓN
# =============================================================================

show_help() {
    cat << EOF
Uso: $0 [OPCIONES]

OPCIONES:
    -h, --help              Muestra esta ayuda
    -y, --yes              Confirmar automáticamente todos los pasos
    --skip-install         Omitir instalación de herramientas
    --config-only          Solo configurar (sin instalar herramientas)
    
FUNCIONES:
    - Instalar herramientas esenciales (kubectl, stern, aws-cli, etc.)
    - Configurar variables de entorno de GitHub y AWS
    - Crear aliases útiles para Kubernetes, Git y AWS
    - Configurar túneles SSH para stage y producción
    - Configurar contextos de Kubernetes
    - Configurar Stern para logs
    - Crear scripts de conexión automatizados

EOF
}

detect_package_manager() {
    if command -v brew &> /dev/null; then
        echo "brew"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

install_tools() {
    section "INSTALACIÓN DE HERRAMIENTAS"
    
    explain "Vamos a instalar las herramientas esenciales para desarrollo:
    • kubectl: Cliente de Kubernetes
    • stern: Para ver logs de múltiples pods
    • aws-cli: CLI de Amazon Web Services  
    • git: Control de versiones
    • jq: Procesador JSON para scripts
    • curl: Para peticiones HTTP
    • ssh: Cliente SSH para túneles"
    
    if ! ask_continue; then return 0; fi
    
    local pkg_mgr=$(detect_package_manager)
    info "Sistema detectado: $OS ($DISTRO)"
    info "Gestor de paquetes: $pkg_mgr"
    
    # Función auxiliar para instalar paquetes
    install_package() {
        local package="$1"
        local brew_name="${2:-$package}"
        local apt_name="${3:-$package}"
        
        if command -v "$package" &> /dev/null; then
            success "$package ya está instalado"
            return 0
        fi
        
        info "Instalando $package..."
        case "$pkg_mgr" in
            "brew")
                brew install "$brew_name" || warning "Error instalando $package con brew"
                ;;
            "apt")
                sudo apt-get update && sudo apt-get install -y "$apt_name" || warning "Error instalando $package con apt"
                ;;
            "yum")
                sudo yum install -y "$apt_name" || warning "Error instalando $package con yum"
                ;;
            *)
                warning "Gestor de paquetes no soportado. Instala $package manualmente"
                return 1
                ;;
        esac
    }
    
    # Instalar herramientas básicas
    install_package "git" "git" "git"
    install_package "curl" "curl" "curl"
    install_package "jq" "jq" "jq"
    
    # Instalar kubectl
    if ! command -v kubectl &> /dev/null; then
        info "Instalando kubectl..."
        case "$OS" in
            "linux")
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
                ;;
            "macos")
                if [[ "$pkg_mgr" == "brew" ]]; then
                    brew install kubectl
                else
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
                    chmod +x kubectl
                    sudo mv kubectl /usr/local/bin/
                fi
                ;;
        esac
        success "kubectl instalado"
    else
        success "kubectl ya está instalado"
    fi
    
    # Instalar stern
    if ! command -v stern &> /dev/null; then
        info "Instalando stern..."
        case "$pkg_mgr" in
            "brew")
                brew install stern
                ;;
            *)
                # Instalar desde GitHub releases
                local stern_version="1.30.0"
                local stern_url="https://github.com/stern/stern/releases/download/v${stern_version}"
                case "$OS" in
                    "linux")
                        curl -L "${stern_url}/stern_${stern_version}_linux_amd64.tar.gz" | tar xz
                        chmod +x stern
                        sudo mv stern /usr/local/bin/
                        ;;
                    "macos")
                        curl -L "${stern_url}/stern_${stern_version}_darwin_amd64.tar.gz" | tar xz
                        chmod +x stern
                        sudo mv stern /usr/local/bin/
                        ;;
                esac
                ;;
        esac
        success "stern instalado"
    else
        success "stern ya está instalado"
    fi
    
    # Instalar AWS CLI
    if ! command -v aws &> /dev/null; then
        info "Instalando AWS CLI..."
        case "$OS" in
            "linux")
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install
                rm -rf aws awscliv2.zip
                ;;
            "macos")
                if [[ "$pkg_mgr" == "brew" ]]; then
                    brew install awscli
                else
                    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
                    sudo installer -pkg AWSCLIV2.pkg -target /
                    rm AWSCLIV2.pkg
                fi
                ;;
        esac
        success "AWS CLI instalado"
    else
        success "AWS CLI ya está instalado"
    fi
    
    # Instalar herramientas adicionales
    install_package "kubectx" "kubectx" "kubectx"
    install_package "kubens" "kubens" "kubens"
    
    success "Instalación de herramientas completada"
}

# =============================================================================
# CONFIGURACIÓN DE GITHUB
# =============================================================================

configure_github() {
    section "CONFIGURACIÓN DE GITHUB"
    
    explain "Configuraremos tu entorno para trabajar con GitHub:
    
    1. Token Personal de GitHub:
       - Ve a GitHub.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
       - Crea un nuevo token con permisos: repo, workflow, user, notifications
       - Copia el token generado
    
    2. Configuración de Git:
       - Nombre de usuario y email
       - Configuraciones globales útiles"
    
    if ! ask_continue; then return 0; fi
    
    # Configurar Git usuario
    echo
    info "=== CONFIGURACIÓN DE GIT ==="
    
    local current_name=$(git config --global user.name 2>/dev/null || echo "")
    local current_email=$(git config --global user.email 2>/dev/null || echo "")
    
    if [[ -n "$current_name" ]]; then
        info "Nombre actual: $current_name"
        read -p "¿Deseas cambiarlo? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Nuevo nombre de usuario Git: " git_name
            git config --global user.name "$git_name"
        fi
    else
        read -p "Nombre de usuario Git: " git_name
        git config --global user.name "$git_name"
    fi
    
    if [[ -n "$current_email" ]]; then
        info "Email actual: $current_email"
        read -p "¿Deseas cambiarlo? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Nuevo email Git: " git_email
            git config --global user.email "$git_email"
        fi
    else
        read -p "Email Git: " git_email
        git config --global user.email "$git_email"
    fi
    
    # Configuraciones útiles de Git
    info "Aplicando configuraciones útiles de Git..."
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global push.default simple
    git config --global core.autocrlf input
    git config --global color.ui auto
    
    # Token de GitHub
    echo
    info "=== TOKEN DE GITHUB ==="
    
    local current_token=$(grep "GITHUB_TOKEN" ~/.bashrc 2>/dev/null | cut -d'=' -f2 | tr -d '"' 2>/dev/null || echo "")
    if [[ -n "$current_token" ]]; then
        info "Ya tienes un token de GitHub configurado"
        read -p "¿Deseas actualizarlo? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    echo
    warning "IMPORTANTE: Necesitas crear un Personal Access Token en GitHub"
    echo "1. Ve a: https://github.com/settings/tokens"
    echo "2. Click en 'Generate new token' → 'Generate new token (classic)'"
    echo "3. Selecciona estos permisos:"
    echo "   ✓ repo (Full control of private repositories)"
    echo "   ✓ workflow (Update GitHub Action workflows)" 
    echo "   ✓ user (Update user information)"
    echo "   ✓ notifications (Access notifications)"
    echo "4. Copia el token generado"
    echo
    
    read -p "¿Ya tienes el token? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Pega tu token de GitHub: " github_token
        echo
        
        # Verificar que el token funciona
        if curl -s -H "Authorization: token $github_token" https://api.github.com/user | jq -r '.login' >/dev/null 2>&1; then
            # Agregar token al archivo de configuración
            backup_file ~/.bashrc
            
            # Remover token anterior si existe
            if [[ "$OS" == "macos" ]]; then
                sed -i '' '/export GITHUB_TOKEN=/d' ~/.bashrc 2>/dev/null || true
            else
                sed -i '/export GITHUB_TOKEN=/d' ~/.bashrc 2>/dev/null || true
            fi
            
            # Agregar nuevo token
            echo "export GITHUB_TOKEN=\"$github_token\"" >> ~/.bashrc
            
            # Configurar gh CLI si está disponible
            if command -v gh &> /dev/null; then
                echo "$github_token" | gh auth login --with-token
                success "GitHub CLI configurado"
            fi
            
            success "Token de GitHub configurado correctamente"
        else
            error "Token de GitHub inválido o sin permisos"
            return 1
        fi
    else
        warning "Configuración de GitHub omitida. Configúrala manualmente más tarde."
    fi
}

# =============================================================================
# CONFIGURACIÓN DE AWS
# =============================================================================

configure_aws() {
    section "CONFIGURACIÓN DE AWS"
    
    explain "Configuraremos AWS CLI con tus credenciales:
    
    1. Access Key ID y Secret Access Key:
       - Ve a AWS Console → IAM → Users → Tu usuario → Security credentials
       - Crea nuevas 'Access keys' si no tienes
       - Copia Access Key ID y Secret Access Key
    
    2. Región por defecto:
       - Ejemplo: us-east-1, us-west-2, eu-west-1
       - Debe coincidir con donde están tus recursos
    
    3. Formato de salida:
       - json (recomendado), table, text, yaml"
    
    if ! ask_continue; then return 0; fi
    
    # Verificar si ya está configurado
    if [[ -f ~/.aws/credentials ]]; then
        info "AWS ya está configurado"
        read -p "¿Deseas reconfigurarlo? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    echo
    info "=== CONFIGURACIÓN DE CREDENCIALES AWS ==="
    
    read -p "AWS Access Key ID: " aws_access_key
    read -p "AWS Secret Access Key: " aws_secret_key
    echo
    read -p "Región por defecto (ej: us-east-1): " aws_region
    read -p "Formato de salida (json): " aws_output
    aws_output="${aws_output:-json}"
    
    # Configurar AWS CLI
    aws configure set aws_access_key_id "$aws_access_key"
    aws configure set aws_secret_access_key "$aws_secret_key"
    aws configure set default.region "$aws_region"
    aws configure set default.output "$aws_output"
    
    # Verificar configuración
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local aws_user=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "unknown")
        success "AWS configurado correctamente para: $aws_user"
        
        # Configurar variables de entorno adicionales
        backup_file ~/.bashrc
        
        # Remover configuraciones anteriores
        if [[ "$OS" == "macos" ]]; then
            sed -i '' '/export AWS_DEFAULT_REGION=/d' ~/.bashrc 2>/dev/null || true
            sed -i '' '/export AWS_REGION=/d' ~/.bashrc 2>/dev/null || true
        else
            sed -i '/export AWS_DEFAULT_REGION=/d' ~/.bashrc 2>/dev/null || true
            sed -i '/export AWS_REGION=/d' ~/.bashrc 2>/dev/null || true
        fi
        
        # Agregar nuevas configuraciones
        cat >> ~/.bashrc << EOF

# AWS Configuration
export AWS_DEFAULT_REGION="$aws_region"
export AWS_REGION="$aws_region"
EOF
        
        success "Variables de entorno AWS configuradas"
    else
        error "Error en la configuración de AWS. Verifica tus credenciales."
        return 1
    fi
}

# =============================================================================
# CONFIGURACIÓN DE TÚNELES SSH
# =============================================================================

configure_ssh_tunnels() {
    section "CONFIGURACIÓN DE TÚNELES SSH"
    
    explain "Crearemos scripts para conectarte a los bastiones de AWS:
    
    1. Bastion de Stage: 
       - Túnel SSH al bastion de staging
       - Acceso al VPC de Kubernetes de stage
    
    2. Bastion de Producción:
       - Túnel SSH al bastion de producción  
       - Acceso al VPC de Kubernetes de producción
    
    Los scripts crearán túneles que permitirán acceso a:
    - Kubernetes API servers
    - Bases de datos internas
    - Servicios internos del VPC"
    
    if ! ask_continue; then return 0; fi
    
    echo
    info "=== CONFIGURACIÓN DE STAGE ==="
    read -p "Host del bastion de stage: " stage_host
    read -p "Usuario SSH para stage (ej: ec2-user): " stage_user
    read -p "Ruta a la clave SSH para stage: " stage_key
    read -p "Puerto local para túnel stage (8001): " stage_port
    stage_port="${stage_port:-8001}"
    
    echo
    info "=== CONFIGURACIÓN DE PRODUCCIÓN ==="
    read -p "Host del bastion de producción: " prod_host
    read -p "Usuario SSH para producción (ej: ec2-user): " prod_user
    read -p "Ruta a la clave SSH para producción: " prod_key
    read -p "Puerto local para túnel producción (8002): " prod_port
    prod_port="${prod_port:-8002}"
    
    # Crear scripts de túneles
    local tunnel_dir="${CONFIG_DIR}/tunnels"
    mkdir -p "$tunnel_dir"
    
    # Script para stage
    cat > "$tunnel_dir/stage-tunnel.sh" << EOF
#!/bin/bash
# Túnel SSH para Stage Environment

BASTION_HOST="$stage_host"
BASTION_USER="$stage_user" 
SSH_KEY="$stage_key"
LOCAL_PORT=$stage_port

echo "🚀 Conectando al bastion de STAGE..."
echo "Host: \$BASTION_HOST"
echo "Usuario: \$BASTION_USER"
echo "Puerto local: \$LOCAL_PORT"
echo

# Verificar que la clave SSH existe
if [[ ! -f "\$SSH_KEY" ]]; then
    echo "❌ Error: Clave SSH no encontrada: \$SSH_KEY"
    exit 1
fi

# Verificar permisos de la clave
chmod 600 "\$SSH_KEY"

echo "📡 Estableciendo túnel SSH..."
echo "Comando: ssh -i \$SSH_KEY -L \$LOCAL_PORT:kubernetes-api.stage:6443 -N \$BASTION_USER@\$BASTION_HOST"
echo
echo "💡 Para conectar kubectl usa:"
echo "   kubectl --server=https://localhost:\$LOCAL_PORT <comando>"
echo
echo "🔴 Para cerrar el túnel: Ctrl+C"
echo

# Establecer túnel (ajustar destino según tu configuración)
ssh -i "\$SSH_KEY" \\
    -L "\$LOCAL_PORT:kubernetes-api.stage:6443" \\
    -L "5432:rds.stage:5432" \\
    -L "6379:redis.stage:6379" \\
    -N "\$BASTION_USER@\$BASTION_HOST"
EOF

    # Script para producción
    cat > "$tunnel_dir/prod-tunnel.sh" << EOF
#!/bin/bash
# Túnel SSH para Production Environment

BASTION_HOST="$prod_host"
BASTION_USER="$prod_user"
SSH_KEY="$prod_key"
LOCAL_PORT=$prod_port

echo "🚀 Conectando al bastion de PRODUCCIÓN..."
echo "Host: \$BASTION_HOST"
echo "Usuario: \$BASTION_USER"
echo "Puerto local: \$LOCAL_PORT"
echo

# Verificar que la clave SSH existe
if [[ ! -f "\$SSH_KEY" ]]; then
    echo "❌ Error: Clave SSH no encontrada: \$SSH_KEY"
    exit 1
fi

# Verificar permisos de la clave
chmod 600 "\$SSH_KEY"

echo "📡 Estableciendo túnel SSH..."
echo "Comando: ssh -i \$SSH_KEY -L \$LOCAL_PORT:kubernetes-api.prod:6443 -N \$BASTION_USER@\$BASTION_HOST"
echo
echo "💡 Para conectar kubectl usa:"
echo "   kubectl --server=https://localhost:\$LOCAL_PORT <comando>"
echo
echo "🔴 Para cerrar el túnel: Ctrl+C"
echo

# Establecer túnel (ajustar destino según tu configuración)
ssh -i "\$SSH_KEY" \\
    -L "\$LOCAL_PORT:kubernetes-api.prod:6443" \\
    -L "5433:rds.prod:5432" \\
    -L "6380:redis.prod:6379" \\
    -N "\$BASTION_USER@\$BASTION_HOST"
EOF

    # Hacer scripts ejecutables
    chmod +x "$tunnel_dir/stage-tunnel.sh"
    chmod +x "$tunnel_dir/prod-tunnel.sh"
    
    success "Scripts de túneles SSH creados en: $tunnel_dir"
    
    # Agregar funciones a bashrc
    backup_file ~/.bashrc
    
    cat >> ~/.bashrc << EOF

# SSH Tunnel Functions
tunnel-stage() {
    echo "🔗 Iniciando túnel a Stage..."
    ${tunnel_dir}/stage-tunnel.sh
}

tunnel-prod() {
    echo "🔗 Iniciando túnel a Producción..."  
    ${tunnel_dir}/prod-tunnel.sh
}

kill-tunnels() {
    echo "🔪 Cerrando todos los túneles SSH..."
    pkill -f "ssh.*-L.*:6443" || echo "No hay túneles activos"
}
EOF

    success "Funciones de túneles agregadas a ~/.bashrc"
}

# =============================================================================
# CONFIGURACIÓN DE KUBERNETES
# =============================================================================

configure_kubernetes() {
    section "CONFIGURACIÓN DE KUBERNETES"
    
    explain "Configuraremos kubectl para trabajar con tus clusters:
    
    1. Contextos de Kubernetes:
       - Stage: Sin namespace (usa default)
       - Producción: Con namespace específico
    
    2. Configuración de kubeconfig:
       - Archivos separados para cada entorno
       - Contextos nombrados claramente
    
    3. Aliases útiles:
       - k = kubectl
       - kgs = kubectl get pods -n stage  
       - kgp = kubectl get pods -n production"
    
    if ! ask_continue; then return 0; fi
    
    local kube_dir="${HOME}/.kube"
    mkdir -p "$kube_dir"
    
    echo
    info "=== CONFIGURACIÓN DE CONTEXTOS ==="
    
    # Información de clusters
    read -p "Nombre del cluster de stage: " stage_cluster
    read -p "URL del API server de stage (ej: https://api.stage.k8s.local): " stage_server
    
    read -p "Nombre del cluster de producción: " prod_cluster  
    read -p "URL del API server de producción: " prod_server
    read -p "Namespace de producción: " prod_namespace
    
    # Crear configuración de stage
    cat > "$kube_dir/config-stage" << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: $stage_server
    insecure-skip-tls-verify: true
  name: $stage_cluster
contexts:
- context:
    cluster: $stage_cluster
    user: $stage_cluster-user
    namespace: default
  name: stage
current-context: stage
users:
- name: $stage_cluster-user
  user:
    # Configurar según tu método de autenticación
    # token: "your-token-here"
    # exec:
    #   command: aws-iam-authenticator
    #   args: ["token", "-i", "$stage_cluster"]
EOF

    # Crear configuración de producción
    cat > "$kube_dir/config-prod" << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: $prod_server
    insecure-skip-tls-verify: true
  name: $prod_cluster
contexts:
- context:
    cluster: $prod_cluster
    user: $prod_cluster-user
    namespace: $prod_namespace
  name: production
current-context: production
users:
- name: $prod_cluster-user
  user:
    # Configurar según tu método de autenticación
    # token: "your-token-here"  
    # exec:
    #   command: aws-iam-authenticator
    #   args: ["token", "-i", "$prod_cluster"]
EOF

    success "Configuraciones de Kubernetes creadas"
    
    # Instalar kubectl-aliases
    info "Descargando kubectl aliases..."
    curl -s https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases -o "$HOME/.kubectl_aliases"
    
    success "kubectl-aliases instalado"
    
    info "=== CONFIGURACIÓN DE ALIASES Y FUNCIONES ==="
    
    # Agregar aliases y funciones a bashrc
    backup_file ~/.bashrc
    
    cat >> ~/.bashrc << EOF

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
alias kgp='kubectl get pods -n $prod_namespace'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias kex='kubectl exec -it'

# Context switching
alias k-stage='export KUBECONFIG=~/.kube/config-stage'
alias k-prod='export KUBECONFIG=~/.kube/config-prod'

# Kubernetes functions
kpods() {
    if [[ "\$1" == "prod" ]]; then
        kubectl get pods -n $prod_namespace
    else
        kubectl get pods
    fi
}

klogs() {
    local env="\$1"
    local app="\$2"
    
    if [[ "\$env" == "prod" ]]; then
        stern "\$app" -n $prod_namespace
    else
        stern "\$app"
    fi
}

kshell() {
    local pod="\$1"
    local env="\$2"
    
    if [[ "\$env" == "prod" ]]; then
        kubectl exec -it "\$pod" -n $prod_namespace -- /bin/bash
    else
        kubectl exec -it "\$pod" -- /bin/bash
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
EOF

    success "Aliases y funciones de Kubernetes configurados"
    
    warning "IMPORTANTE: Debes configurar la autenticación en los archivos kubeconfig:"
    warning "  - ~/.kube/config-stage"
    warning "  - ~/.kube/config-prod"
    warning "Agrega tokens o configuración de aws-iam-authenticator según tu setup"
}

# =============================================================================
# CONFIGURACIÓN DE STERN Y LOGS  
# =============================================================================

configure_stern() {
    section "CONFIGURACIÓN DE STERN PARA LOGS"
    
    explain "Stern te permite ver logs de múltiples pods simultáneamente:
    
    Funciones que configuraremos:
    - logs-stage <app>: Ver logs en stage
    - logs-prod <app>: Ver logs en producción  
    - logs-all <app>: Ver logs en ambos entornos
    
    Ejemplos de uso:
    - logs-stage nginx
    - logs-prod api
    - logs-all frontend"
    
    if ! ask_continue; then return 0; fi
    
    # Configurar stern
    backup_file ~/.bashrc
    
    cat >> ~/.bashrc << EOF

# =============================================================================
# STERN CONFIGURATION FOR LOGS
# =============================================================================

# Stern functions for different environments
logs-stage() {
    local app="\$1"
    if [[ -z "\$app" ]]; then
        echo "Uso: logs-stage <nombre-app>"
        echo "Ejemplo: logs-stage nginx"
        return 1
    fi
    
    echo "📋 Mostrando logs de \$app en STAGE..."
    export KUBECONFIG=~/.kube/config-stage
    stern "\$app" --tail=50 --color=always
}

logs-prod() {
    local app="\$1"  
    if [[ -z "\$app" ]]; then
        echo "Uso: logs-prod <nombre-app>"
        echo "Ejemplo: logs-prod api"
        return 1
    fi
    
    echo "📋 Mostrando logs de \$app en PRODUCCIÓN..."
    export KUBECONFIG=~/.kube/config-prod
    stern "\$app" -n $prod_namespace --tail=50 --color=always
}

logs-all() {
    local app="\$1"
    if [[ -z "\$app" ]]; then
        echo "Uso: logs-all <nombre-app>"
        echo "Ejemplo: logs-all frontend"
        return 1
    fi
    
    echo "📋 Mostrando logs de \$app en AMBOS entornos..."
    
    # Stage en una ventana
    export KUBECONFIG=~/.kube/config-stage
    stern "\$app" --tail=10 --color=always --prefix="[STAGE]" &
    local stage_pid=\$!
    
    # Production en otra ventana
    export KUBECONFIG=~/.kube/config-prod  
    stern "\$app" -n $prod_namespace --tail=10 --color=always --prefix="[PROD]" &
    local prod_pid=\$!
    
    # Función para limpiar al salir
    cleanup_logs() {
        kill \$stage_pid \$prod_pid 2>/dev/null || true
        echo "🔴 Logs cerrados"
    }
    
    trap cleanup_logs EXIT
    wait
}

# Función para mostrar pods disponibles
list-apps() {
    local env="\$1"
    
    case "\$env" in
        "stage")
            echo "📱 Apps disponibles en STAGE:"
            export KUBECONFIG=~/.kube/config-stage
            kubectl get pods -o jsonpath='{range .items[*]}{.metadata.labels.app}{"\n"}{end}' | sort -u | grep -v '^$'
            ;;
        "prod")
            echo "📱 Apps disponibles en PRODUCCIÓN:"
            export KUBECONFIG=~/.kube/config-prod
            kubectl get pods -n $prod_namespace -o jsonpath='{range .items[*]}{.metadata.labels.app}{"\n"}{end}' | sort -u | grep -v '^$'
            ;;
        *)
            echo "Uso: list-apps [stage|prod]"
            echo "Ejemplo: list-apps stage"
            ;;
    esac
}
EOF

    success "Configuración de Stern completada"
}

# =============================================================================
# ALIASES ADICIONALES
# =============================================================================

configure_additional_aliases() {
    section "ALIASES Y FUNCIONES ADICIONALES"
    
    explain "Configuraremos aliases útiles para:
    
    Git:
    - gs = git status
    - ga = git add
    - gc = git commit
    - gp = git push
    
    AWS:
    - awsprofile = cambiar perfil AWS
    - ec2list = listar instancias EC2
    
    Sistema:
    - ll = ls -la
    - la = ls -A
    - ports = ver puertos abiertos"
    
    if ! ask_continue; then return 0; fi
    
    backup_file ~/.bashrc
    
    cat >> ~/.bashrc << EOF

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
alias ec2-list='aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==\`Name\`].Value|[0]]" --output table'
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
    mkdir -p "\$1" && cd "\$1"
}

extract() {
    if [ -f "\$1" ]; then
        case "\$1" in
            *.tar.bz2)   tar xvjf "\$1"    ;;
            *.tar.gz)    tar xvzf "\$1"    ;;
            *.bz2)       bunzip2 "\$1"     ;;
            *.rar)       unrar x "\$1"     ;;
            *.gz)        gunzip "\$1"      ;;
            *.tar)       tar xvf "\$1"     ;;
            *.tbz2)      tar xvjf "\$1"    ;;
            *.tgz)       tar xvzf "\$1"    ;;
            *.zip)       unzip "\$1"       ;;
            *.Z)         uncompress "\$1"  ;;
            *.7z)        7z x "\$1"        ;;
            *)           echo "No sé cómo extraer '\$1'..." ;;
        esac
    else
        echo "'\$1' no es un archivo válido"
    fi
}

# Show environment info
devenv-info() {
    echo "🔧 INFORMACIÓN DEL ENTORNO DE DESARROLLO"
    echo "========================================"
    echo
    echo "📍 Sistema: \$(uname -s) \$(uname -r)"
    echo "📍 Shell: \$SHELL"
    echo "📍 Usuario: \$(whoami)"
    echo "📍 Directorio: \$(pwd)"
    echo
    echo "🐙 Git:"
    echo "   Usuario: \$(git config --global user.name)"
    echo "   Email: \$(git config --global user.email)"
    echo
    echo "☁️ AWS:"
    echo "   Región: \${AWS_REGION:-No configurada}"
    echo "   Usuario: \$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo 'No configurado')"
    echo
    echo "⚓ Kubernetes:"
    echo "   Context actual: \$(kubectl config current-context 2>/dev/null || echo 'No configurado')"
    echo "   Namespace: \$(kubectl config view --minify --output 'jsonpath={.contexts[0].context.namespace}' 2>/dev/null || echo 'default')"
    echo
    echo "🔧 Herramientas:"
    command -v kubectl >/dev/null && echo "   ✅ kubectl \$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)"
    command -v stern >/dev/null && echo "   ✅ stern \$(stern --version 2>/dev/null | cut -d' ' -f3)"
    command -v aws >/dev/null && echo "   ✅ aws-cli \$(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"
    command -v git >/dev/null && echo "   ✅ git \$(git --version | cut -d' ' -f3)"
    command -v jq >/dev/null && echo "   ✅ jq \$(jq --version | tr -d '\"')"
}
EOF

    success "Aliases adicionales configurados"
}

# =============================================================================
# CONFIGURACIÓN FINAL Y CLEANUP
# =============================================================================

finalize_setup() {
    section "FINALIZACIÓN DE LA CONFIGURACIÓN"
    
    # Hacer que el .bashrc sea ejecutable y reload
    chmod +x ~/.bashrc
    
    # Crear un archivo de información del setup
    cat > "${CONFIG_DIR}/setup-info.txt" << EOF
=============================================================================
INFORMACIÓN DE CONFIGURACIÓN DEL ENTORNO DE DESARROLLO
=============================================================================

Fecha de configuración: $(date)
Sistema: $OS ($DISTRO)
Usuario: $(whoami)

ARCHIVOS CREADOS:
- ~/.bashrc (modificado con aliases y funciones)
- ${CONFIG_DIR}/tunnels/stage-tunnel.sh
- ${CONFIG_DIR}/tunnels/prod-tunnel.sh  
- ~/.kube/config-stage
- ~/.kube/config-prod
- ~/.kubectl_aliases

COMANDOS DISPONIBLES:

Túneles SSH:
- tunnel-stage    : Conectar a bastion de stage
- tunnel-prod     : Conectar a bastion de producción
- kill-tunnels    : Cerrar todos los túneles

Kubernetes:
- k-stage         : Cambiar contexto a stage
- k-prod          : Cambiar contexto a producción
- kpods [env]     : Ver pods (env: stage|prod)
- klogs <app> <env> : Ver logs con stern
- kshell <pod> <env> : Shell en pod

Logs:
- logs-stage <app> : Logs en stage
- logs-prod <app>  : Logs en producción  
- logs-all <app>   : Logs en ambos entornos
- list-apps <env>  : Listar apps disponibles

Información:
- devenv-info     : Mostrar información del entorno

PRÓXIMOS PASOS:
1. Ejecuta: source ~/.bashrc
2. Configura autenticación en ~/.kube/config-stage y ~/.kube/config-prod
3. Prueba las conexiones con: k-stage-connect o k-prod-connect
4. Verifica con: devenv-info

=============================================================================
EOF

    success "Configuración completada exitosamente!"
    
    echo
    info "📋 RESUMEN DE LA CONFIGURACIÓN:"
    echo "  ✅ Herramientas instaladas (kubectl, stern, aws-cli)"
    echo "  ✅ GitHub configurado con token"
    echo "  ✅ AWS CLI configurado" 
    echo "  ✅ Túneles SSH configurados"
    echo "  ✅ Contextos de Kubernetes creados"
    echo "  ✅ Stern configurado para logs"
    echo "  ✅ Aliases y funciones útiles agregados"
    
    echo
    warning "🔧 ACCIONES REQUERIDAS:"
    echo "1. Ejecutar: source ~/.bashrc"
    echo "2. Configurar autenticación en archivos kubeconfig"
    echo "3. Verificar conexiones SSH"
    
    echo
    info "📖 Ver información completa en: ${CONFIG_DIR}/setup-info.txt"
    echo "📖 Logs de instalación en: $LOG_FILE"
    
    echo
    success "🎉 ¡Tu entorno de desarrollo está listo!"
    echo
    echo "Para empezar:"
    echo "  source ~/.bashrc"
    echo "  devenv-info"
    echo "  tunnel-stage  # o tunnel-prod"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    local auto_confirm="false"
    local skip_install="false"
    local config_only="false"
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -y|--yes)
                auto_confirm="true"
                shift
                ;;
            --skip-install)
                skip_install="true"
                shift
                ;;
            --config-only)
                config_only="true"
                skip_install="true"
                shift
                ;;
            *)
                error "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Mostrar banner
    section "CONFIGURADOR DE ENTORNO DE DESARROLLO"
    echo "Sistema detectado: $OS ($DISTRO)"
    echo "Este script configurará tu entorno completo para desarrollo con:"
    echo "  • GitHub y Git"
    echo "  • AWS CLI y credenciales" 
    echo "  • Kubernetes (kubectl, stern, aliases)"
    echo "  • Túneles SSH a bastiones AWS"
    echo "  • Aliases y funciones útiles"
    
    # Crear directorios
    create_dirs
    
    if [[ "$auto_confirm" == "true" ]]; then
        info "Modo automático activado - se confirmarán todos los pasos"
    fi
    
    # Ejecutar configuraciones
    if [[ "$skip_install" != "true" ]]; then
        install_tools
    fi
    
    configure_github
    configure_aws  
    configure_ssh_tunnels
    configure_kubernetes
    configure_stern
    configure_additional_aliases
    finalize_setup
    
    return 0
}

# Ejecutar función principal
main "$@"
