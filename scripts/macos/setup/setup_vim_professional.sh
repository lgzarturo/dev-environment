#!/bin/bash

# Script de Configuración Vim Profesional para Desarrollo Full Stack
# Versión: 1.0
# Descripción: Instala y configura Vim con plugins profesionales para PHP, React, Next.js, Python, TypeScript, JavaScript, Markdown

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

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

success() {
    echo -e "${CYAN}[SUCCESS] $1${NC}"
}

# Verificar si se ejecuta como usuario normal
check_user() {
    if [[ $EUID -eq 0 ]]; then
        error "No ejecutes este script como root."
        exit 1
    fi
}

# Función para hacer backup
backup_config() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backup creado: ${file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Función para instalar dependencias del sistema
install_system_dependencies() {
    log "=== INSTALANDO DEPENDENCIAS DEL SISTEMA ==="

    # Actualizar repositorios
    log "Actualizando repositorios..."
    sudo apt update

    # Instalar Vim y herramientas necesarias
    log "Instalando Vim y dependencias..."
    sudo apt install -y \
        vim \
        curl \
        wget \
        git \
        nodejs \
        python3 \
        python3-pip \
        php \
        php-cli \
        php-mbstring \
        php-xml \
        ripgrep \
        fd-find \
        universal-ctags \
        silversearcher-ag \
        fzf \
        build-essential \
        cmake \
        unzip

    # Instalar Node.js LTS (si no está actualizado)
    if ! node --version | grep -q "v1[8-9]\|v[2-9][0-9]"; then
        log "Instalando Node.js LTS..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    # Instalar Yarn
    if ! command -v yarn &> /dev/null; then
        log "Instalando Yarn..."
        curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
        echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
        sudo apt update && sudo apt install -y yarn
    fi

    # Instalar Python packages necesarios
    #log "Instalando paquetes Python necesarios..."
    #pip3 install --user pynvim jedi autopep8 black flake8 mypy pylint
    if ! command -v pipx &> /dev/null; then
    	sudo apt install pipx -y
    	pipx ensurepath
    	pipx install black
    	pipx install flake8
    	pipx install mypy
    fi

    # Instalar Composer para PHP
    if ! command -v composer &> /dev/null; then
        log "Instalando Composer..."
        curl -sS https://getcomposer.org/installer | php
        sudo mv composer.phar /usr/local/bin/composer
        sudo chmod +x /usr/local/bin/composer
    fi

    success "Dependencias del sistema instaladas correctamente."
}

# Función para instalar vim-plug
install_vim_plug() {
    log "=== INSTALANDO VIM-PLUG ==="

    # Crear directorios necesarios
    mkdir -p ~/.vim/autoload ~/.vim/plugged

    # Descargar vim-plug
    if [[ ! -f ~/.vim/autoload/plug.vim ]]; then
        log "Descargando vim-plug..."
        curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi

    success "vim-plug instalado correctamente."
}

# Función para crear configuración .vimrc
create_vimrc() {
    log "=== CREANDO CONFIGURACIÓN .vimrc ==="

    # Backup del .vimrc actual
    backup_config "$HOME/.vimrc"

    # Crear .vimrc optimizado
    cat > "$HOME/.vimrc" << 'EOF'
" ================================================================
" VIM CONFIGURATION PROFESIONAL PARA DESARROLLO FULL STACK
" ================================================================

" ================================================================
" CONFIGURACIÓN BÁSICA
" ================================================================
set nocompatible              " Disable compatibility mode
filetype off                  " Required for Vundle

" Encoding
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8
set bomb
set binary

" Fix backspace indent
set backspace=indent,eol,start

" Tabs and indentation
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent

" Display settings
set number
set relativenumber
set ruler
set wrap
set linebreak
set showmatch
set showmode
set showcmd
set cmdheight=1
set laststatus=2

" Search settings
set hlsearch
set incsearch
set ignorecase
set smartcase

" Performance
set lazyredraw
set ttyfast
set updatetime=300
set timeoutlen=500

" File handling
set autoread
set autowrite
set hidden
set backup
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//
set undofile
set undodir=~/.vim/undo//

" Create backup directories if they don't exist
if !isdirectory($HOME."/.vim/backup")
    call mkdir($HOME."/.vim/backup", "p")
endif
if !isdirectory($HOME."/.vim/swap")
    call mkdir($HOME."/.vim/swap", "p")
endif
if !isdirectory($HOME."/.vim/undo")
    call mkdir($HOME."/.vim/undo", "p")
endif

" Mouse support
set mouse=a

" Clipboard
set clipboard=unnamedplus

" ================================================================
" PLUGINS - VIM-PLUG
" ================================================================
call plug#begin('~/.vim/plugged')

" === APARIENCIA Y TEMAS ===
Plug 'morhetz/gruvbox'                    " Tema Gruvbox
Plug 'vim-airline/vim-airline'            " Barra de estado
Plug 'vim-airline/vim-airline-themes'     " Temas para airline
Plug 'ryanoasis/vim-devicons'             " Iconos de archivos
Plug 'Yggdroot/indentLine'                " Líneas de indentación

" === NAVEGACIÓN Y BÚSQUEDA ===
Plug 'preservim/nerdtree'                 " Explorador de archivos
Plug 'Xuyuanp/nerdtree-git-plugin'       " Git para NERDTree
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'                  " Búsqueda fuzzy
Plug 'easymotion/vim-easymotion'          " Navegación rápida

" === AUTOCOMPLETADO Y COC ===
Plug 'neoclide/coc.nvim', {'branch': 'release'}  " Autocompletado inteligente
Plug 'github/copilot.vim'                " GitHub Copilot

" === GIT ===
Plug 'tpope/vim-fugitive'                " Git integration
Plug 'airblade/vim-gitgutter'            " Git diff in gutter
Plug 'junegunn/gv.vim'                   " Git commit browser

" === EDICIÓN ===
Plug 'tpope/vim-surround'                " Surrounding text objects
Plug 'tpope/vim-commentary'              " Comentarios
Plug 'jiangmiao/auto-pairs'              " Auto-pairing brackets
Plug 'tpope/vim-repeat'                  " Repeat plugin commands
Plug 'vim-scripts/ReplaceWithRegister'   " Replace with register

" === LENGUAJES DE PROGRAMACIÓN ===
Plug 'sheerun/vim-polyglot'              " Syntax highlighting para múltiples lenguajes

" === PHP ===
Plug 'phpactor/phpactor', {'for': 'php', 'branch': 'master', 'do': 'composer install --no-dev -o'}
Plug 'stephpy/vim-php-cs-fixer'          " PHP CS Fixer
Plug '2072/PHP-Indenting-for-VIm'        " PHP indentation

" === JAVASCRIPT/TYPESCRIPT/REACT ===
Plug 'pangloss/vim-javascript'           " JavaScript syntax
Plug 'leafgarland/typescript-vim'        " TypeScript syntax
Plug 'peitalin/vim-jsx-typescript'       " JSX/TSX syntax
Plug 'maxmellon/vim-jsx-pretty'          " JSX pretty
Plug 'styled-components/vim-styled-components', { 'branch': 'main' }

" === PYTHON ===
Plug 'vim-python/python-syntax'          " Enhanced Python syntax
Plug 'Vimjas/vim-python-pep8-indent'     " PEP8 indentation

" === HTML/CSS ===
Plug 'mattn/emmet-vim'                   " Emmet for HTML/CSS
Plug 'hail2u/vim-css3-syntax'           " CSS3 syntax

" === MARKDOWN ===
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && yarn install' }
Plug 'plasticboy/vim-markdown'           " Markdown syntax

" === UTILIDADES ===
Plug 'mbbill/undotree'                   " Undo tree
Plug 'junegunn/vim-easy-align'           " Easy alignment
Plug 'tpope/vim-sleuth'                  " Auto-detect indentation

call plug#end()

" ================================================================
" CONFIGURACIÓN DE TEMA
" ================================================================
" Gruvbox theme
set background=dark
colorscheme gruvbox
let g:gruvbox_contrast_dark = 'medium'

" Airline configuration
let g:airline_theme = 'gruvbox'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
let g:airline_powerline_fonts = 1

" ================================================================
" CONFIGURACIÓN DE PLUGINS
" ================================================================

" === NERDTREE ===
let NERDTreeShowHidden=1
let NERDTreeIgnore=['\.pyc$', '\.pyo$', '\.rbc$', '\.rbo$', '\.class$', '\.o$', '\~$']
let g:NERDTreeWinSize=35
let g:NERDTreeMinimalUI=1
let g:NERDTreeDirArrows=1
let g:NERDTreeAutoDeleteBuffer=1

" === FZF ===
let g:fzf_layout = { 'down': '~40%' }
let g:fzf_colors = {
  \ 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment']
  \ }

" === COC.NVIM ===
let g:coc_global_extensions = [
  \ 'coc-json',
  \ 'coc-tsserver',
  \ 'coc-html',
  \ 'coc-css',
  \ 'coc-phpls',
  \ 'coc-python',
  \ 'coc-emmet',
  \ 'coc-prettier',
  \ 'coc-eslint',
  \ 'coc-snippets',
  \ 'coc-pairs',
  \ 'coc-marketplace'
  \ ]

" === GITHUB COPILOT ===
let g:copilot_no_tab_map = v:true
let g:copilot_assume_mapped = v:true

" === EMMET ===
let g:user_emmet_leader_key='<C-Z>'
let g:user_emmet_settings = {
\  'javascript.jsx' : {
    \      'extends' : 'jsx',
    \  },
\}

" === MARKDOWN PREVIEW ===
let g:mkdp_auto_start = 0
let g:mkdp_auto_close = 1
let g:mkdp_refresh_slow = 0
let g:mkdp_command_for_global = 0
let g:mkdp_open_to_the_world = 0
let g:mkdp_open_ip = ''
let g:mkdp_browser = ''
let g:mkdp_echo_preview_url = 0
let g:mkdp_browserfunc = ''
let g:mkdp_preview_options = {
    \ 'mkit': {},
    \ 'katex': {},
    \ 'uml': {},
    \ 'maid': {},
    \ 'disable_sync_scroll': 0,
    \ 'sync_scroll_type': 'middle',
    \ 'hide_yaml_meta': 1,
    \ 'sequence_diagrams': {},
    \ 'flowchart_diagrams': {},
    \ 'content_editable': v:false,
    \ 'disable_filename': 0
    \ }

" === INDENT LINE ===
let g:indentLine_char = '│'
let g:indentLine_first_char = '│'
let g:indentLine_showFirstIndentLevel = 1
let g:indentLine_setColors = 0

" === PHP CS FIXER ===
let g:php_cs_fixer_rules = "@PSR2"
let g:php_cs_fixer_php_path = "php"

" ================================================================
" MAPAS DE TECLAS
" ================================================================

" Leader key
let mapleader = " "

" === BÁSICOS ===
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>
nnoremap <leader>Q :q!<CR>

" Navegación entre ventanas
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Redimensionar ventanas
nnoremap <silent> <leader>+ :vertical resize +5<CR>
nnoremap <silent> <leader>- :vertical resize -5<CR>

" === NERDTREE ===
nnoremap <leader>e :NERDTreeToggle<CR>
nnoremap <leader>f :NERDTreeFind<CR>

" === FZF ===
nnoremap <leader>p :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>h :History<CR>
nnoremap <leader>t :Tags<CR>
nnoremap <leader>l :Lines<CR>
nnoremap <leader>/ :Rg<Space>
nnoremap <leader>: :Commands<CR>

" === COC.NVIM ===
" Use tab for trigger completion with characters ahead and navigate.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Make <CR> auto-select the first completion item
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" Formatting selected code.
xmap <leader>fo  <Plug>(coc-format-selected)
nmap <leader>fo  <Plug>(coc-format-selected)

" === GITHUB COPILOT ===
imap <silent><script><expr> <C-G> copilot#Accept("\<CR>")
imap <C-]> <Plug>(copilot-dismiss)
imap <C-\> <Plug>(copilot-next)
imap <C-[> <Plug>(copilot-previous)
imap <C-Right> <Plug>(copilot-accept-word)

" === GIT ===
nnoremap <leader>gs :Git<CR>
nnoremap <leader>gc :Git commit<CR>
nnoremap <leader>gp :Git push<CR>
nnoremap <leader>gl :Git pull<CR>
nnoremap <leader>gd :Gdiffsplit<CR>
nnoremap <leader>gb :Git blame<CR>

" === UNDOTREE ===
nnoremap <leader>u :UndotreeToggle<CR>

" === MARKDOWN PREVIEW ===
nnoremap <leader>mp :MarkdownPreview<CR>
nnoremap <leader>ms :MarkdownPreviewStop<CR>

" === UTILIDADES ===
" Clear search highlighting
nnoremap <leader><space> :nohlsearch<CR>

" Quick edit vimrc
nnoremap <leader>ev :edit $MYVIMRC<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>

" Toggle paste mode
nnoremap <leader>pp :set paste!<CR>

" === DESARROLLO ESPECÍFICO ===
" PHP CS Fixer
autocmd FileType php nnoremap <leader>pcf :call PhpCsFixerFixFile()<CR>

" Python formatting with Black
autocmd FileType python nnoremap <leader>bf :!black %<CR>

" JavaScript/TypeScript formatting with Prettier
autocmd FileType javascript,typescript,json,css,html nnoremap <leader>pf :CocCommand prettier.formatFile<CR>

" ================================================================
" AUTOCOMMANDS
" ================================================================
augroup vimrc
  autocmd!

  " Restore cursor position
  autocmd BufReadPost * if line("'"") > 0 && line("'"") <= line("$") | exe "normal! g`"" | endif

  " Remove trailing whitespace on save
  autocmd BufWritePre * :%s/\s\+$//e

  " Auto close NERDTree if it's the only window left
  autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

  " Set specific file types
  autocmd BufRead,BufNewFile *.tsx set filetype=typescript.tsx
  autocmd BufRead,BufNewFile *.jsx set filetype=javascript.jsx

  " PHP specific settings
  autocmd FileType php setlocal tabstop=4 shiftwidth=4 expandtab

  " JavaScript/TypeScript specific settings
  autocmd FileType javascript,typescript,json setlocal tabstop=2 shiftwidth=2 expandtab

  " HTML/CSS specific settings
  autocmd FileType html,css,scss setlocal tabstop=2 shiftwidth=2 expandtab

  " Python specific settings
  autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab

augroup END

" ================================================================
" FUNCIONES PERSONALIZADAS
" ================================================================

" Función para alternar números relativos
function! NumberToggle()
  if(&relativenumber == 1)
    set norelativenumber
  else
    set relativenumber
  endif
endfunc
nnoremap <leader>n :call NumberToggle()<CR>

" Función para crear archivos desde Vim
function! CreateFile(filename)
  execute 'edit ' . a:filename
endfunction
command! -nargs=1 Create call CreateFile(<f-args>)

" Función para abrir terminal
function! OpenTerminal()
  terminal
  startinsert
endfunction
nnoremap <leader>term :call OpenTerminal()<CR>

" ================================================================
" CONFIGURACIÓN FINAL
" ================================================================
filetype plugin indent on
syntax enable

" Habilitar mouse en todos los modos
if has('mouse')
  set mouse=a
endif

" Optimización para archivos grandes
set synmaxcol=200
set ttyfast
set lazyredraw

" Configuración de split
set splitbelow
set splitright

" Configuración de búsqueda
set path+=**
set wildmenu
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*.pyc,*.db,*.sqlite,*node_modules*

" Mensaje de bienvenida personalizado
autocmd VimEnter * if argc() == 0 | echo "🚀 Vim Profesional para Desarrollo Full Stack cargado correctamente!" | endif
EOF

    success ".vimrc creado correctamente."
}

# Función para instalar plugins
install_plugins() {
    log "=== INSTALANDO PLUGINS DE VIM ==="

    log "Ejecutando PlugInstall..."
    vim +PlugInstall +qall

    # Instalar extensiones de CoC
    log "Instalando extensiones de CoC.nvim..."
    vim -c 'CocInstall -sync coc-json coc-tsserver coc-html coc-css coc-phpls coc-python coc-emmet coc-prettier coc-eslint coc-snippets coc-pairs coc-marketplace|q'

    success "Plugins instalados correctamente."
}

# Función para configurar GitHub Copilot
setup_copilot() {
    log "=== CONFIGURANDO GITHUB COPILOT ==="

    warning "Para usar GitHub Copilot, necesitas:"
    echo "1. Una suscripción activa a GitHub Copilot"
    echo "2. Autenticarte con tu cuenta de GitHub"
    echo ""

    read -p "¿Deseas configurar GitHub Copilot ahora? (y/n): " setup_copilot_now

    if [[ "$setup_copilot_now" == "y" ]]; then
        log "Iniciando configuración de Copilot..."
        echo "Ejecuta el siguiente comando en Vim:"
        echo ":Copilot setup"
        echo ""
        warning "Después de configurar Copilot, reinicia Vim."
    else
        info "Puedes configurar Copilot más tarde ejecutando ':Copilot setup' en Vim."
    fi
}

# Función para crear archivos de configuración adicionales
create_additional_configs() {
    log "=== CREANDO ARCHIVOS DE CONFIGURACIÓN ADICIONALES ==="

    # Crear configuración de CoC
    mkdir -p ~/.vim/coc-settings
    cat > ~/.vim/coc-settings.json << 'EOF'
{
  "suggest.noselect": false,
  "suggest.enablePreview": true,
  "suggest.enablePreselect": false,
  "suggest.triggerAfterInsertEnter": true,
  "suggest.timeout": 2000,
  "suggest.minTriggerInputLength": 1,
  "suggest.snippetIndicator": " ►",
  "suggest.maxCompleteItemCount": 50,

  "diagnostic.enable": true,
  "diagnostic.level": "warning",
  "diagnostic.refreshOnInsertMode": false,
  "diagnostic.virtualText": true,
  "diagnostic.checkCurrentLine": true,

  "codeLens.enable": true,

  "coc.preferences.formatOnSave": true,
  "coc.preferences.hoverTarget": "float",

  "typescript.preferences.includePackageJsonAutoImports": "auto",
  "typescript.updateImportsOnFileMove.enabled": "always",
  "typescript.suggest.autoImports": true,
  "typescript.format.insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces": false,

  "javascript.preferences.includePackageJsonAutoImports": "auto",
  "javascript.updateImportsOnFileMove.enabled": "always",
  "javascript.suggest.autoImports": true,
  "javascript.format.insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces": false,

  "html.filetypes": ["html", "handlebars", "htmldjango", "blade"],
  "emmet.includeLanguages": {
    "javascript": "javascriptreact",
    "typescript": "typescriptreact"
  },

  "prettier.requireConfig": false,
  "prettier.onlyUseLocalVersion": false,
  "prettier.disableSuccessMessage": true,

  "python.linting.enabled": true,
  "python.linting.flake8Enabled": true,
  "python.formatting.provider": "black",
  "python.formatting.blackArgs": ["--line-length=88"],

  "php.suggest.basic": false,
  "phpls.path": "phpactor"
}
EOF

    # Crear snippets personalizados
    mkdir -p ~/.vim/UltiSnips

    # Snippets para JavaScript/React
    cat > ~/.vim/UltiSnips/javascript.snippets << 'EOF'
snippet rfc "React Functional Component"
import React from 'react';

const ${1:ComponentName} = () => {
  return (
    <div>
      ${2:// Component content}
    </div>
  );
};

export default $1;
endsnippet

snippet useState "React useState Hook"
const [${1:state}, set${1/(.)/\u$1/}] = useState(${2:initialValue});
endsnippet

snippet useEffect "React useEffect Hook"
useEffect(() => {
  ${1:// Effect logic}
}, [${2:dependencies}]);
endsnippet
EOF

    # Snippets para PHP
    cat > ~/.vim/UltiSnips/php.snippets << 'EOF'
snippet class "PHP Class"
<?php

class ${1:ClassName}
{
    ${2:// Class content}
}
endsnippet

snippet func "PHP Function"
public function ${1:functionName}(${2:parameters})
{
    ${3:// Function content}
}
endsnippet
EOF

    success "Archivos de configuración adicionales creados."
}

# Función para verificar instalación
verify_installation() {
    log "=== VERIFICANDO INSTALACIÓN ==="

    info "Verificando componentes instalados:"

    # Verificar Vim
    if command -v vim &> /dev/null; then
        success "✓ Vim: $(vim --version | head -1)"
    else
        error "✗ Vim no está instalado"
    fi

    # Verificar Node.js
    if command -v node &> /dev/null; then
        success "✓ Node.js: $(node --version)"
    else
        warning "✗ Node.js no está instalado"
    fi

    # Verificar Python
    if command -v python3 &> /dev/null; then
        success "✓ Python: $(python3 --version)"
    else
        warning "✗ Python3 no está instalado"
    fi

    # Verificar PHP
    if command -v php &> /dev/null; then
        success "✓ PHP: $(php --version | head -1)"
    else
        warning "✗ PHP no está instalado"
    fi

    # Verificar plugins de Vim
    if [[ -f ~/.vim/autoload/plug.vim ]]; then
        success "✓ vim-plug instalado"
    else
        error "✗ vim-plug no está instalado"
    fi

    if [[ -f ~/.vimrc ]]; then
        success "✓ .vimrc configurado"
        info "Plugins configurados: $(grep -c "Plug '" ~/.vimrc) plugins"
    else
        error "✗ .vimrc no está configurado"
    fi
}

# Función para mostrar guía de uso
show_usage_guide() {
    log "=== GUÍA DE USO RÁPIDO ==="

    echo -e "${CYAN}"
    cat << 'EOF'
🚀 COMANDOS PRINCIPALES DE VIM PROFESIONAL

=== NAVEGACIÓN ===
<Space>e          - Abrir/cerrar explorador de archivos (NERDTree)
<Space>f          - Encontrar archivo actual en NERDTree
<Space>p          - Búsqueda de archivos (FZF)
<Space>b          - Lista de buffers
<Space>/          - Búsqueda en archivos (Ripgrep)

=== AUTOCOMPLETADO (CoC) ===
<Tab>             - Navegar autocompletado
<Ctrl-Space>      - Activar autocompletado
gd                - Ir a definición
gr                - Ver referencias
K                 - Ver documentación
<Space>rn         - Renombrar símbolo

=== GITHUB COPILOT ===
<Ctrl-G>          - Aceptar sugerencia
<Ctrl-]>          - Descartar sugerencia
<Ctrl-\>          - Siguiente sugerencia
<Ctrl-[>          - Sugerencia anterior

=== GIT ===
<Space>gs         - Estado de Git
<Space>gc         - Commit
<Space>gd         - Diff
<Space>gb         - Blame

=== DESARROLLO ===
<Space>pcf        - PHP CS Fixer (archivos PHP)
<Space>bf         - Black formatter (archivos Python)
<Space>pf         - Prettier (JS/TS/JSON/CSS/HTML)
<Space>mp         - Preview Markdown

=== UTILIDADES ===
<Space>w          - Guardar archivo
<Space>q          - Cerrar ventana
<Space>u          - Undo tree
<Space><Space>    - Limpiar resaltado de búsqueda
<Space>term       - Abrir terminal

EOF
    echo -e "${NC}"

    info "Para más comandos, consulta el archivo ~/.vimrc"
}

# Función principal
main() {
    check_user

    log "🚀 Configuración Vim Profesional para Desarrollo Full Stack"
    log "Este script configurará Vim con plugins para PHP, React, Next.js, Python, TypeScript, JavaScript y Markdown"

    echo -e "${YELLOW}"
    echo "¿Qué componentes deseas instalar?"
    echo "1) Instalación completa (recomendado)"
    echo "2) Solo dependencias del sistema"
    echo "3) Solo configuración de Vim"
    echo "4) Solo plugins"
    echo "5) Solo configuración de Copilot"
    echo "6) Personalizado"
    echo -e "${NC}"

    read -p "Selecciona una opción (1-6): " choice

    case $choice in
        1)
            install_system_dependencies
            install_vim_plug
            create_vimrc
            create_additional_configs
            install_plugins
            setup_copilot
            ;;
        2)
            install_system_dependencies
            ;;
        3)
            install_vim_plug
            create_vimrc
            create_additional_configs
            ;;
        4)
            install_plugins
            ;;
        5)
            setup_copilot
            ;;
        6)
            echo "Selecciona los componentes a instalar:"
            read -p "¿Instalar dependencias del sistema? (y/n): " opt_deps
            read -p "¿Instalar vim-plug? (y/n): " opt_plug
            read -p "¿Crear configuración .vimrc? (y/n): " opt_vimrc
            read -p "¿Crear configuraciones adicionales? (y/n): " opt_configs
            read -p "¿Instalar plugins? (y/n): " opt_plugins
            read -p "¿Configurar Copilot? (y/n): " opt_copilot

            [[ "$opt_deps" == "y" ]] && install_system_dependencies
            [[ "$opt_plug" == "y" ]] && install_vim_plug
            [[ "$opt_vimrc" == "y" ]] && create_vimrc
            [[ "$opt_configs" == "y" ]] && create_additional_configs
            [[ "$opt_plugins" == "y" ]] && install_plugins
            [[ "$opt_copilot" == "y" ]] && setup_copilot
            ;;
        *)
            error "Opción inválida"
            exit 1
            ;;
    esac

    verify_installation
    show_usage_guide

    log "=== CONFIGURACIÓN COMPLETADA ==="
    success "🎉 Vim está listo para desarrollo profesional!"

    warning "NOTAS IMPORTANTES:"
    echo "• Reinicia tu terminal para aplicar todos los cambios"
    echo "• La primera vez que abras Vim, los plugins pueden tardar en cargar"
    echo "• Para GitHub Copilot, ejecuta ':Copilot setup' en Vim"
    echo "• Usa '<Space>ev' para editar .vimrc y '<Space>sv' para recargarlo"

    info "¡Disfruta programando con tu nuevo entorno Vim profesional! 🚀"
}

# Ejecutar función principal
main "$@"
