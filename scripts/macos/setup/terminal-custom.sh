#!/usr/bin/env bash
set -euo pipefail

# Script para personalizar zsh (añade al ~/.zshrc)
ZSHRC="$HOME/.zshrc"

# 1. Instalar zsh si no existe
#if ! command -v zsh >/dev/null; then
#  sudo apt-get update
#  sudo apt-get install -y zsh
#fi

# 2. Instalar Oh My Zsh si no existe
#if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
#  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
#fi

# 3. Añadir plugins y configuraciones
cat >> "$ZSHRC" << 'EOF'
# --- Personalización by setup_zshrc_env.sh ---
# Tema obscuro con colores neon
theme_name="agnoster"
ZSH_THEME="$theme_name"

# Plugins útiles
plugins=(
  git
  z
  history
  extract
  autojump
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Historial mejorado
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# Búsqueda de documentos con 'z'
# z plugin ya instalado para directorios frecuentes

# Colores neón
# Prompt personalizado
enable_prompt_string="%F{magenta}%n@%m %F{cyan}%~ %F{yellow}→ %f"
PROMPT="$enable_prompt_string"
RPROMPT="%F{green}%*%f"

# Optimización
export HISTIGNORE='&:[ ]*'
export LESS=-R

# Cargar cambios
source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
EOF

# 4. Aplicar configuración
echo "Recarga ~/.zshrc o abre nueva terminal para ver cambios."

