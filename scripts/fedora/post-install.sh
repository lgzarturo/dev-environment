#!/bin/bash

set -e

# Colores para progreso
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

function step {
  echo -e "\n${CYAN}>>> $1${RESET}"
}


echo "🚀 Iniciando configuración post-instalación para Xubuntu..."

# --- Actualizar sistema ---
step "📦 Actualizando sistema..."
sudo apt update && sudo apt upgrade -y

# --- Instalar paquetes esenciales ---
step "🔧 Instalando herramientas base..."
sudo apt install -y \
    git curl wget htop build-essential gnome-disk-utility software-properties-common \
    preload tlp zram-config ufw fail2ban unattended-upgrades \
    vlc gparted xclip unzip flatpak gnupg2 ca-certificates apt-transport-https \
    zsh fonts-firacode bat fzf

# --- Optimizaciones ---
step "⚙️ Configurando TRIM (discard)"
sudo sed -i 's/errors=remount-ro/errors=remount-ro,discard/' /etc/fstab

step "⚙️ Instalando Oh My Zsh y tema Powerlevel10k"
if ! command -v zsh >/dev/null; then
  sudo apt install -y zsh
fi
RUNZSH=no KEEP_ZSHRC=yes sh -c \
  "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
sed -i 's/ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
# Clonar plugins
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-history-substring-search.git $ZSH_CUSTOM/plugins/zsh-history-substring-search
git clone https://github.com/zsh-users/zsh-completions.git $ZSH_CUSTOM/plugins/zsh-completions
# Actualizar .zshrc
sed -i 's/plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search zsh-completions fzf bat)/' ~/.zshrc

step "⚙️ Instalando fuentes y configurando terminal"
fc-cache -fv

# --- Activar servicios ---
step "⚙️ Activando servicios de optimización y seguridad..."
sudo systemctl enable tlp
sudo ufw enable
sudo dpkg-reconfigure --priority=low unattended-upgrades

# --- Configurar TRIM ---
step "🧹 Activando TRIM para USB (discard)..."
sudo sed -i 's/errors=remount-ro/errors=remount-ro,discard/' /etc/fstab

# --- Instalar Java ---
step "☕ Instalando OpenJDK 17..."
sudo apt install -y openjdk-17-jdk

# --- Instalar Python y pip ---
step "🐍 Instalando Python y pip..."
sudo apt install -y python3 python3-pip python3-venv

# --- Instalar Node.js y Yarn ---
step "🧶 Instalando Node.js y Yarn..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g yarn

# --- Instalar Docker ---
step "🐳 Instalando Docker..."
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
sudo systemctl enable docker

# PostgreSQL
step "Iniciando contenedor de PostgreSQL"
docker run -d --name pg_dev -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 postgres:latest
# MongoDB
step "Iniciando contenedor de MongoDB"
docker run -d --name mongo_dev -p 27017:27017 mongo:latest
# Redis
step "Iniciando contenedor de Redis"
docker run -d --name redis_dev -p 6379:6379 redis:latest

# -- Instalar Ollama ---
step "Instalando Ollama y modelo Gemma3"
# Instalar Ollama
echo "Instalando Ollama..."
if ! command -v ollama >/dev/null; then
  curl -fsSL https://ollama.com/install.sh | sudo sh
fi

# Descargar modelo
echo "Descargando modelo Gemma3:1b-it-fp16..."
ollama pull gemma3:1b-it-fp16

# --- Instalar VS Code ---
step "🖥️ Instalando VS Code y extensiones..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install -y code
rm packages.microsoft.gpg

# Extensiones
code --install-extension ms-python.python
code --install-extension ms-azuretools.vscode-docker
code --install-extension eamodio.gitlens
code --install-extension ms-vscode.vscode-typescript-next
code --install-extension ollama.ollama-vscode

# Configurar autocompletado Ollama en settings
mkdir -p ~/.config/Code/User
cat > ~/.config/Code/User/settings.json <<EOF
{
  "workbench.colorTheme": "Monokai Dimmed",
  "editor.fontFamily": "Fira Code",
  "editor.fontLigatures": true,
  "ollama.model": "gemma3:1b-it-fp16",
  "editor.quickSuggestions": {
    "other": true,
    "comments": false,
    "strings": true
  }
}
EOF

# --- Instalar LibreOffice ---
step "📄 Instalando LibreOffice..."
sudo apt install -y libreoffice libreoffice-l10n-es

# --- Instalar Flatpak y apps extra ---
step "📦 Configurando Flatpak..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub

# --- Limpiar sistema ---
step "🧼 Limpiando sistema..."
sudo apt autoremove -y
sudo apt autoclean

step "✅ Configuración finalizada. Reinicia para aplicar todos los cambios."
echo -e "\n${GREEN}✔️  Post-instalación completa.
Reinicia el sistema para aplicar todos los cambios.${RESET}"
