#!/bin/bash

# =============================================================================
# macOS Developer Setup Script
# =============================================================================
# Configura macOS para desarrollo con las herramientas y configuraciones
# recomendadas para desarrolladores
# =============================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/setup.log"
PROGRESS_FILE="${SCRIPT_DIR}/.setup_progress"
SKIP_FILE="${SCRIPT_DIR}/.setup_skip"

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

print_header() {
    echo -e "\n${PURPLE}=================================================================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${PURPLE}=================================================================================${NC}\n"
}

print_step() {
    echo -e "${CYAN}[PASO]${NC} $1"
    echo "[$(date)] PASO: $1" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    echo "[$(date)] ÉXITO: $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    echo "[$(date)] ADVERTENCIA: $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    echo "[$(date)] ERROR: $1" >> "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date)] INFO: $1" >> "$LOG_FILE"
}

# Función para marcar paso como completado
mark_completed() {
    echo "$1" >> "$PROGRESS_FILE"
}

# Función para verificar si un paso ya está completado
is_completed() {
    [[ -f "$PROGRESS_FILE" ]] && grep -q "^$1$" "$PROGRESS_FILE" 2>/dev/null
}

# Función para marcar paso como omitido
mark_skipped() {
    echo "$1" >> "$SKIP_FILE"
}

# Función para verificar si un paso debe ser omitido
is_skipped() {
    [[ -f "$SKIP_FILE" ]] && grep -q "^$1$" "$SKIP_FILE" 2>/dev/null
}

# Función para manejar errores
handle_error() {
    local step="$1"
    local error_msg="$2"
    
    print_error "$error_msg"
    echo ""
    echo -e "${YELLOW}¿Qué deseas hacer?${NC}"
    echo "1) Reintentar este paso"
    echo "2) Omitir este paso y continuar"
    echo "3) Salir del script"
    
    while true; do
        read -p "Selecciona una opción (1/2/3): " choice
        case $choice in
            1) return 1 ;; # Reintentar
            2) 
                mark_skipped "$step"
                print_warning "Paso '$step' omitido por el usuario"
                return 0 ;; # Omitir
            3) 
                print_info "Script terminado por el usuario"
                exit 0 ;;
            *) echo "Opción inválida. Por favor selecciona 1, 2, o 3." ;;
        esac
    done
}

# Función para ejecutar paso con manejo de errores
execute_step() {
    local step_name="$1"
    local step_function="$2"
    
    if is_completed "$step_name"; then
        print_success "$step_name - Ya completado"
        return 0
    fi
    
    if is_skipped "$step_name"; then
        print_warning "$step_name - Omitido anteriormente"
        return 0
    fi
    
    while true; do
        print_step "Ejecutando: $step_name"
        if $step_function; then
            mark_completed "$step_name"
            print_success "$step_name - Completado"
            break
        else
            if ! handle_error "$step_name" "Error al ejecutar: $step_name"; then
                continue # Reintentar
            else
                break # Omitir
            fi
        fi
    done
}

# Verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar si un paquete de brew está instalado
brew_package_exists() {
    brew list "$1" >/dev/null 2>&1
}

# =============================================================================
# FUNCIONES DE INSTALACIÓN
# =============================================================================

verify_homebrew() {
    if ! command_exists brew; then
        print_error "Homebrew no está instalado. Por favor instálalo primero desde https://brew.sh/"
        exit 1
    fi
    print_success "Homebrew verificado"
}

update_homebrew() {
    print_step "Actualizando Homebrew..."
    brew update
    brew upgrade
}

install_basic_tools() {
    local tools=("neofetch" "unzip" "rar" "bat" "eza" "curl" "wget" "htop" "tree" "fzf" "ripgrep" "fd" "jq" "xmlstarlet" "ffmpeg" "imagemagick")
    
    for tool in "${tools[@]}"; do
        if brew_package_exists "$tool"; then
            print_success "$tool ya está instalado"
        else
            print_step "Instalando $tool..."
            brew install "$tool"
            print_success "$tool instalado"
        fi
    done
}

install_python() {
    if brew_package_exists python3 || command_exists python3; then
        print_success "Python3 ya está instalado"
    else
        print_step "Instalando Python3..."
        brew install python3
        print_success "Python3 instalado"
    fi
    
    # Instalar pip packages útiles
    print_step "Instalando paquetes de Python útiles..."
    python3 -m pip install --user --upgrade pip setuptools wheel
    python3 -m pip install --user neovim pynvim
}

install_nvm_node() {
    if [[ -d "$HOME/.nvm" ]]; then
        print_success "NVM ya está instalado"
    else
        print_step "Instalando NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        
        # Cargar NVM en la sesión actual
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        
        print_success "NVM instalado"
    fi
    
    # Instalar la última versión LTS de Node
    if command_exists nvm; then
        print_step "Instalando Node.js LTS..."
        nvm install --lts
        nvm use --lts
        nvm alias default node
        print_success "Node.js LTS instalado"
    fi
}

setup_zsh() {
    # Cambiar a zsh si no es el shell por defecto
    if [[ "$SHELL" != */zsh ]]; then
        print_step "Cambiando shell a zsh..."
        chsh -s /bin/zsh
        print_success "Shell cambiado a zsh"
    else
        print_success "Zsh ya es el shell por defecto"
    fi
}

install_oh_my_zsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        print_success "Oh-My-Zsh ya está instalado"
    else
        print_step "Instalando Oh-My-Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        print_success "Oh-My-Zsh instalado"
    fi
}

install_zsh_plugins() {
    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    
    # zsh-autosuggestions
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
        print_step "Instalando zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
        print_success "zsh-autosuggestions instalado"
    else
        print_success "zsh-autosuggestions ya está instalado"
    fi
    
    # zsh-syntax-highlighting
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
        print_step "Instalando zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
        print_success "zsh-syntax-highlighting instalado"
    else
        print_success "zsh-syntax-highlighting ya está instalado"
    fi
    
    # zsh-completions
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]]; then
        print_step "Instalando zsh-completions..."
        git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions
        print_success "zsh-completions instalado"
    else
        print_success "zsh-completions ya está instalado"
    fi
    
    # powerlevel10k theme
    if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
        print_step "Instalando tema Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
        print_success "Powerlevel10k instalado"
    else
        print_success "Powerlevel10k ya está instalado"
    fi
}

configure_zshrc() {
    local ZSHRC="$HOME/.zshrc"
    local BACKUP_ZSHRC="${ZSHRC}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Hacer backup del .zshrc actual
    if [[ -f "$ZSHRC" ]]; then
        cp "$ZSHRC" "$BACKUP_ZSHRC"
        print_info "Backup de .zshrc creado en $BACKUP_ZSHRC"
    fi
    
    print_step "Configurando .zshrc..."
    
    cat > "$ZSHRC" << 'EOF'
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
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='nvim'
export VISUAL='nvim'

# Aliases
alias ll='eza -la --icons --git'
alias la='eza -la --icons --git'
alias ls='eza --icons'
alias cat='bat'
alias find='fd'
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

# FZF configuration
export FZF_DEFAULT_COMMAND='fd --type f'
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
EOF
    
    print_success ".zshrc configurado"
}

install_neovim() {
    if brew_package_exists neovim; then
        print_success "Neovim ya está instalado"
    else
        print_step "Instalando Neovim..."
        brew install neovim
        print_success "Neovim instalado"
    fi
}

setup_neovim_config() {
    local NVIM_CONFIG_DIR="$HOME/.config/nvim"
    local BACKUP_DIR="$HOME/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Backup existing config
    if [[ -d "$NVIM_CONFIG_DIR" ]]; then
        mv "$NVIM_CONFIG_DIR" "$BACKUP_DIR"
        print_info "Backup de configuración de Neovim creado en $BACKUP_DIR"
    fi
    
    mkdir -p "$NVIM_CONFIG_DIR"
    
    print_step "Configurando Neovim..."
    
    # Crear init.lua
    cat > "$NVIM_CONFIG_DIR/init.lua" << 'EOF'
-- Configuración básica de Neovim para desarrollo

-- Configuración general
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Opciones básicas
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.completeopt = 'menuone,noselect'
vim.opt.termguicolors = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- Lazy.nvim setup
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin setup
require("lazy").setup({
  -- Tema
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme "catppuccin"
    end,
  },

  -- Statusline
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },

  -- File explorer
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require("nvim-tree").setup({
        disable_netrw = true,
        hijack_netrw = true,
      })
    end,
  },

  -- Telescope (búsqueda difusa)
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('telescope').setup{}
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
      vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
    end,
  },

  -- Treesitter (syntax highlighting)
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = { "lua", "python", "javascript", "typescript", "html", "css", "json", "yaml", "bash" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- LSP
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "pyright", "tsserver" },
      })
      
      local lspconfig = require('lspconfig')
      lspconfig.lua_ls.setup{}
      lspconfig.pyright.setup{}
      lspconfig.tsserver.setup{}
    end,
  },

  -- Autocompletion
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      local cmp = require('cmp')
      local luasnip = require('luasnip')
      
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
        }, {
          { name = 'buffer' },
        })
      })
    end,
  },

  -- Git integration
  {
    'lewis6991/gitsigns.nvim',
    opts = {},
  },

  -- Which-key (muestra atajos de teclado)
  {
    'folke/which-key.nvim',
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {},
  },

  -- Auto pairs
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    opts = {},
  },

  -- Comment
  {
    'numToStr/Comment.nvim',
    opts = {},
    lazy = false,
  },

  -- Indent blankline
  {
    'lukas-reineke/indent-blankline.nvim',
    main = "ibl",
    opts = {},
  },
})

-- Key mappings
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>w', ':w<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>q', ':q<CR>', { noremap = true, silent = true })

-- Better window navigation
vim.keymap.set('n', '<C-h>', '<C-w>h', { noremap = true, silent = true })
vim.keymap.set('n', '<C-j>', '<C-w>j', { noremap = true, silent = true })
vim.keymap.set('n', '<C-k>', '<C-w>k', { noremap = true, silent = true })
vim.keymap.set('n', '<C-l>', '<C-w>l', { noremap = true, silent = true })

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
EOF
    
    print_success "Configuración de Neovim creada"
}

install_fonts() {
    print_step "Instalando fuentes para desarrolladores..."
    
    # Nerd Fonts para iconos en terminal
    brew tap homebrew/cask-fonts
    
    local fonts=("font-fira-code-nerd-font" "font-jetbrains-mono-nerd-font" "font-hack-nerd-font")
    
    for font in "${fonts[@]}"; do
        if brew list --cask "$font" >/dev/null 2>&1; then
            print_success "$font ya está instalado"
        else
            print_step "Instalando $font..."
            brew install --cask "$font"
            print_success "$font instalado"
        fi
    done
}

configure_git() {
    if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
        print_step "Configurando Git..."
        echo -e "${YELLOW}Configuración de Git:${NC}"
        read -p "Nombre completo: " git_name
        read -p "Email: " git_email
        
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        git config --global init.defaultBranch main
        git config --global core.editor nvim
        git config --global pull.rebase false
        
        print_success "Git configurado"
    else
        print_success "Git ya está configurado"
    fi
}

setup_macos_preferences() {
    print_step "Configurando preferencias de macOS para desarrollo..."
    
    # Mostrar archivos ocultos en Finder
    defaults write com.apple.finder AppleShowAllFiles -bool true
    
    # Mostrar extensiones de archivos
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    
    # Deshabilitar advertencia al cambiar extensión
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
    
    # Usar vista de lista como vista por defecto en Finder
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    
    # Mostrar barra de path en Finder
    defaults write com.apple.finder ShowPathbar -bool true
    
    # Mostrar barra de estado en Finder
    defaults write com.apple.finder ShowStatusBar -bool true
    
    # Configurar Dock
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock tilesize -int 50
    
    # Configurar trackpad para desarrollo
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    
    # Configurar teclado
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15
    
    # Reiniciar servicios afectados
    killall Finder
    killall Dock
    killall SystemUIServer
    
    print_success "Preferencias de macOS configuradas"
}

create_development_directories() {
    print_step "Creando estructura de directorios para desarrollo..."
    
    local dirs=("$HOME/Development" "$HOME/Development/personal" "$HOME/Development/work" "$HOME/Development/learning" "$HOME/.local/bin")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            print_success "Directorio creado: $dir"
        else
            print_success "Directorio ya existe: $dir"
        fi
    done
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    # Limpiar pantalla y mostrar header
    clear
    print_header "CONFIGURADOR DE DESARROLLO PARA macOS SEQUOIA"
    
    # Inicializar archivos de log y progreso
    touch "$LOG_FILE" "$PROGRESS_FILE" "$SKIP_FILE"
    
    print_info "Iniciando configuración de desarrollo para macOS"
    print_info "Log: $LOG_FILE"
    print_info "Progreso: $PROGRESS_FILE"
    
    # Ejecutar pasos
    execute_step "verify_homebrew" verify_homebrew
    execute_step "update_homebrew" update_homebrew
    execute_step "install_basic_tools" install_basic_tools
    execute_step "install_python" install_python
    execute_step "install_nvm_node" install_nvm_node
    execute_step "setup_zsh" setup_zsh
    execute_step "install_oh_my_zsh" install_oh_my_zsh
    execute_step "install_zsh_plugins" install_zsh_plugins
    execute_step "configure_zshrc" configure_zshrc
    execute_step "install_neovim" install_neovim
    execute_step "setup_neovim_config" setup_neovim_config
    execute_step "install_fonts" install_fonts
    execute_step "configure_git" configure_git
    execute_step "setup_macos_preferences" setup_macos_preferences
    execute_step "create_development_directories" create_development_directories
    
    # Mensaje final
    print_header "CONFIGURACIÓN COMPLETADA"
    print_success "¡Tu macOS está configurado para desarrollo!"
    echo ""
    print_info "Pasos siguientes:"
    echo "1. Reinicia tu terminal o ejecuta: source ~/.zshrc"
    echo "2. Configura Powerlevel10k ejecutando: p10k configure"
    echo "3. Abre Neovim y los plugins se instalarán automáticamente"
    echo "4. Revisa el log en: $LOG_FILE"
    echo ""
    print_info "¡Happy coding! 🚀"
}

# Ejecutar función principal si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi