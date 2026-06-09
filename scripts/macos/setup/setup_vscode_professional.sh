#!/bin/bash

# Script de Configuración VS Code Profesional para Desarrollo Full Stack
# Versión: 1.0
# Descripción: Instala y configura VS Code con extensiones profesionales para PHP, React, Next.js, Python, TypeScript, JavaScript, Markdown

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

    # Instalar herramientas necesarias
    log "Instalando herramientas básicas..."
    sudo apt install -y \
        curl \
        wget \
        git \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        python3 \
        python3-pip \
        php \
        php-cli \
        php-mbstring \
        php-xml \
        php-curl \
        php-zip \
        php-gd \
        ripgrep \
        fd-find \
        tree

    # Instalar Node.js LTS (si no está actualizado)
    if ! node --version | grep -q "v1[8-9]\|v[2-9][0-9]"; then
        log "Instalando Node.js LTS..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    # Instalar Yarn
    if ! command -v yarn &> /dev/null; then
        log "Instalando Yarn..."
        npm install -g yarn
    fi

    # Instalar Python packages necesarios
    #log "Instalando paquetes Python necesarios..."
    #pip3 install --user black autopep8 flake8 mypy pylint isort

    # Instalar Composer para PHP
    if ! command -v composer &> /dev/null; then
        log "Instalando Composer..."
        curl -sS https://getcomposer.org/installer | php
        sudo mv composer.phar /usr/local/bin/composer
        sudo chmod +x /usr/local/bin/composer
    fi

    success "Dependencias del sistema instaladas correctamente."
}

# Función para instalar VS Code
install_vscode() {
    log "=== INSTALANDO VISUAL STUDIO CODE ==="

    if command -v code &> /dev/null; then
        info "VS Code ya está instalado: $(code --version | head -1)"
        return 0
    fi

    log "Descargando e instalando VS Code..."

    # Agregar repositorio de Microsoft
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

    # Instalar VS Code
    sudo apt update
    sudo apt install -y code

    # Limpiar archivo temporal
    rm -f packages.microsoft.gpg

    success "VS Code instalado correctamente."
}

# Función para instalar extensiones
install_extensions() {
    log "=== INSTALANDO EXTENSIONES DE VS CODE ==="

    # Lista de extensiones profesionales
    local extensions=(
        # === TEMAS Y APARIENCIA ===
        "zhuangtongfa.material-theme"              # One Dark Pro
        "PKief.material-icon-theme"                # Material Icon Theme
        "aaron-bond.better-comments"               # Better Comments
        "CoenraadS.bracket-pair-colorizer-2"       # Bracket Pair Colorizer 2
        "oderwat.indent-rainbow"                   # Indent Rainbow

        # === GIT Y VERSIONADO ===
        "eamodio.gitlens"                         # GitLens
        "donjayamanne.githistory"                 # Git History
        "mhutchie.git-graph"                      # Git Graph
        "github.vscode-pull-request-github"       # GitHub Pull Requests

        # === GITHUB COPILOT ===
        "github.copilot"                          # GitHub Copilot
        "github.copilot-chat"                     # GitHub Copilot Chat

        # === AUTOCOMPLETADO Y UTILIDADES ===
        "visualstudioexptteam.vscodeintellicode"  # IntelliCode
        "ms-vscode.vscode-typescript-next"        # TypeScript Importer
        "christian-kohler.path-intellisense"      # Path Intellisense
        "formulahendry.auto-rename-tag"           # Auto Rename Tag
        "formulahendry.auto-close-tag"            # Auto Close Tag
        "streetsidesoftware.code-spell-checker"   # Code Spell Checker

        # === FORMATEO Y LINTING ===
        "esbenp.prettier-vscode"                  # Prettier
        "dbaeumer.vscode-eslint"                  # ESLint
        "ms-python.isort"                         # isort
        "ms-python.black-formatter"               # Black Formatter

        # === JAVASCRIPT/TYPESCRIPT/REACT ===
        "dsznajder.es7-react-js-snippets"        # ES7+ React/Redux/React-Native snippets
        "bradlc.vscode-tailwindcss"              # Tailwind CSS IntelliSense
        #"steoates.autoimport-es6-ts"             # Auto Import - ES6, TS, JSX, TSX
        #"jpoissonnier.vscode-styled-components"   # vscode-styled-components
        #"ms-vscode.vscode-json"                   # JSON
        "firefox-devtools.vscode-firefox-debug"  # Debugger for Firefox
        #"ms-vscode.vscode-js-debug"              # JavaScript Debugger

        # === NEXT.JS ===
        "PulkitGangwar.nextjs-snippets"          # Next.js snippets
        "bradlc.vscode-tailwindcss"              # Tailwind CSS (útil para Next.js)

        # === PHP ===
        "bmewburn.vscode-intelephense-client"    # PHP Intelephense
        "junstyle.php-cs-fixer"                  # PHP CS Fixer
        #"felixfbecker.php-debug"                 # PHP Debug
        "devsense.phptools-vscode"               # PHP Tools
        "rifi2k.format-html-in-php"             # Format HTML in PHP

        # === PYTHON ===
        "ms-python.python"                       # Python
        "ms-python.pylint"                       # Pylint
        "ms-python.mypy-type-checker"            # Mypy Type Checker
        "ms-toolsai.jupyter"                     # Jupyter
        "ms-toolsai.vscode-jupyter-cell-tags"    # Jupyter Cell Tags
        "ms-toolsai.vscode-jupyter-slideshow"    # Jupyter Slide Show

        # === HTML/CSS ===
        "ritwickdey.liveserver"                  # Live Server
        "formulahendry.auto-rename-tag"          # Auto Rename Tag
        "bradlc.vscode-tailwindcss"             # Tailwind CSS IntelliSense
        "zignd.html-css-class-completion"        # IntelliSense for CSS class names in HTML
        "pranaygp.vscode-css-peek"               # CSS Peek

        # === MARKDOWN ===
        "yzhang.markdown-all-in-one"             # Markdown All in One
        "shd101wyy.markdown-preview-enhanced"    # Markdown Preview Enhanced
        "davidanson.vscode-markdownlint"         # markdownlint
        "bierner.markdown-mermaid"               # Markdown Mermaid

        # === BASES DE DATOS ===
        "ms-mssql.mssql"                        # SQL Server (mssql)
        "formulahendry.vscode-mysql"             # MySQL
        "cweijan.vscode-mysql-client2"          # MySQL Client

        # === DOCKER Y DEVOPS ===
        "ms-azuretools.vscode-docker"           # Docker
        "ms-vscode-remote.remote-containers"     # Dev Containers
        "hashicorp.terraform"                    # HashiCorp Terraform

        # === UTILIDADES AVANZADAS ===
        "ms-vscode.vscode-typescript-next"       # TypeScript Importer
        "gruntfuggly.todo-tree"                 # Todo Tree
        "alefragnani.bookmarks"                  # Bookmarks
        "ms-vscode.hexeditor"                    # Hex Editor
        "usernamehw.errorlens"                   # Error Lens
        "tombonnike.vscode-status-bar-format-toggle" # Status Bar Format Toggle

        # === SERVIDOR DE DESARROLLO ===
        "ritwickdey.liveserver"                  # Live Server
        "ms-vscode.live-server"                  # Live Preview

        # === TESTING ===
        "hbenl.vscode-test-explorer"            # Test Explorer UI
        "ms-vscode.test-adapter-converter"       # Test Adapter Converter

        # === REST CLIENT ===
        "humao.rest-client"                      # REST Client

        # === SNIPPETS ADICIONALES ===
        "christian-kohler.npm-intellisense"      # npm Intellisense
        "eg2.vscode-npm-script"                  # npm
        "ms-vscode.vscode-node-azure-pack"      # Azure Tools
    )

    log "Instalando ${#extensions[@]} extensiones..."

    for extension in "${extensions[@]}"; do
        log "Instalando: $extension"
        code --install-extension "$extension" --force
    done

    success "Extensiones instaladas correctamente."
}

# Función para crear configuración settings.json
create_settings() {
    log "=== CREANDO CONFIGURACIÓN SETTINGS.JSON ==="

    # Crear directorio de configuración de VS Code
    local config_dir="$HOME/.config/Code/User"
    mkdir -p "$config_dir"

    # Backup del settings.json actual
    backup_config "$config_dir/settings.json"

    # Crear configuración optimizada
    cat > "$config_dir/settings.json" << 'EOF'
{
  // ================================================================
  // CONFIGURACIÓN GENERAL
  // ================================================================
  "workbench.colorTheme": "One Dark Pro",
  "workbench.iconTheme": "material-icon-theme",
  "workbench.startupEditor": "welcomePage",
  "window.zoomLevel": 0,
  "editor.fontSize": 14,
  "editor.fontFamily": "'Fira Code', 'Cascadia Code', 'JetBrains Mono', Consolas, 'Courier New', monospace",
  "editor.fontLigatures": true,
  "editor.lineHeight": 1.5,
  "editor.cursorBlinking": "smooth",
  "editor.cursorSmoothCaretAnimation": "on",
  "editor.smoothScrolling": true,

  // ================================================================
  // CONFIGURACIÓN DEL EDITOR
  // ================================================================
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  "editor.detectIndentation": true,
  "editor.renderWhitespace": "boundary",
  "editor.rulers": [80, 120],
  "editor.wordWrap": "on",
  "editor.minimap.enabled": true,
  "editor.minimap.maxColumn": 120,
  "editor.scrollBeyondLastLine": false,
  "editor.renderLineHighlight": "gutter",
  "editor.highlightActiveIndentGuide": true,
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": true,

  // ================================================================
  // AUTOGUARDADO Y FORMATEO
  // ================================================================
  "files.autoSave": "onFocusChange",
  "editor.formatOnSave": true,
  "editor.formatOnPaste": true,
  "editor.formatOnType": false,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit",
    "source.organizeImports": "explicit"
  },

  // ================================================================
  // AUTOCOMPLETADO Y SUGERENCIAS
  // ================================================================
  "editor.suggestSelection": "first",
  "editor.acceptSuggestionOnCommitCharacter": true,
  "editor.acceptSuggestionOnEnter": "on",
  "editor.tabCompletion": "on",
  "editor.quickSuggestions": {
    "other": true,
    "comments": false,
    "strings": true
  },
  "editor.parameterHints.enabled": true,
  "editor.hover.enabled": true,
  "editor.hover.delay": 300,

  // ================================================================
  // GITHUB COPILOT
  // ================================================================
  "github.copilot.enable": {
    "*": true,
    "yaml": false,
    "plaintext": false,
    "markdown": true
  },
  "github.copilot.inlineSuggest.enable": true,
  "github.copilot.advanced": {},

  // ================================================================
  // CONFIGURACIÓN POR LENGUAJE
  // ================================================================

  // JavaScript/TypeScript
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2,
    "editor.codeActionsOnSave": {
      "source.fixAll.eslint": "explicit"
    }
  },
  "[javascriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2,
    "editor.codeActionsOnSave": {
      "source.fixAll.eslint": "explicit"
    }
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2
  },

  // JSON
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2
  },
  "[jsonc]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2
  },

  // HTML/CSS
  "[html]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2
  },
  "[css]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2
  },
  "[scss]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.tabSize": 2
  },

  // PHP
  "[php]": {
    "editor.defaultFormatter": "junstyle.php-cs-fixer",
    "editor.tabSize": 4,
    "editor.insertSpaces": true
  },

  // Python
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.codeActionsOnSave": {
      "source.organizeImports": "explicit"
    }
  },

  // Markdown
  "[markdown]": {
    "editor.defaultFormatter": "yzhang.markdown-all-in-one",
    "editor.tabSize": 2,
    "editor.wordWrap": "on",
    "editor.quickSuggestions": {
      "comments": "off",
      "strings": "off",
      "other": "off"
    }
  },

  // ================================================================
  // CONFIGURACIÓN DE EXTENSIONES
  // ================================================================

  // Prettier
  "prettier.semi": true,
  "prettier.singleQuote": true,
  "prettier.trailingComma": "es5",
  "prettier.tabWidth": 2,
  "prettier.printWidth": 80,
  "prettier.bracketSpacing": true,
  "prettier.arrowParens": "avoid",

  // ESLint
  "eslint.enable": true,
  "eslint.alwaysShowStatus": true,
  "eslint.format.enable": true,

  // PHP
  "php.suggest.basic": false,
  "php.validate.enable": true,
  "php-cs-fixer.onsave": true,
  "php-cs-fixer.rules": "@PSR12",
  "intelephense.diagnostics.enable": true,
  "intelephense.completion.triggerParameterHints": true,

  // Python
  "python.defaultInterpreterPath": "/usr/bin/python3",
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.linting.flake8Enabled": true,
  "python.formatting.blackArgs": ["--line-length=88"],
  "python.analysis.typeCheckingMode": "basic",

  // Git
  "git.enableSmartCommit": true,
  "git.confirmSync": false,
  "git.autofetch": true,
  "git.decorations.enabled": true,

  // GitLens
  "gitlens.currentLine.enabled": true,
  "gitlens.hovers.currentLine.over": "line",
  "gitlens.blame.format": "${message|50?} ${agoOrDate|14-}",
  "gitlens.defaultDateFormat": "MMMM Do, YYYY h:mma",
  "gitlens.defaultDateShortFormat": "MMM D, YYYY",

  // Live Server
  "liveServer.settings.donotShowInfoMsg": true,
  "liveServer.settings.donotVerifyTags": true,

  // Terminal
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.fontFamily": "'Fira Code', 'Cascadia Code', monospace",
  "terminal.integrated.shell.linux": "/bin/zsh",
  "terminal.integrated.cursorBlinking": true,
  "terminal.integrated.cursorStyle": "line",

  // Explorador de archivos
  "explorer.confirmDelete": false,
  "explorer.confirmDragAndDrop": false,
  "explorer.compactFolders": false,
  "explorer.openEditors.visible": 0,

  // ================================================================
  // CONFIGURACIÓN DE BÚSQUEDA
  // ================================================================
  "search.exclude": {
    "**/node_modules": true,
    "**/bower_components": true,
    "**/*.code-search": true,
    "**/vendor": true,
    "**/dist": true,
    "**/build": true,
    "**/.git": true,
    "**/.DS_Store": true,
    "**/Thumbs.db": true
  },
  "files.exclude": {
    "**/.git": true,
    "**/.svn": true,
    "**/.hg": true,
    "**/CVS": true,
    "**/.DS_Store": true,
    "**/Thumbs.db": true,
    "**/node_modules": false
  },
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/**": true,
    "**/vendor/**": true,
    "**/dist/**": true,
    "**/build/**": true
  },

  // ================================================================
  // CONFIGURACIÓN DE RENDIMIENTO
  // ================================================================
  "files.hotExit": "onExitAndWindowClose",
  "editor.accessibilitySupport": "off",
  "workbench.editor.enablePreview": false,
  "workbench.editor.enablePreviewFromQuickOpen": false,
  "extensions.ignoreRecommendations": false,

  // ================================================================
  // CONFIGURACIÓN DE EMMET
  // ================================================================
  "emmet.includeLanguages": {
    "javascript": "javascriptreact",
    "typescript": "typescriptreact"
  },
  "emmet.triggerExpansionOnTab": true,
  "emmet.showSuggestionsAsSnippets": true,

  // ================================================================
  // CONFIGURACIÓN ADICIONAL
  // ================================================================
  "breadcrumbs.enabled": true,
  "workbench.activityBar.location": "default",
  "workbench.editor.showTabs": "multiple",
  "workbench.editor.tabSizing": "fit",
  "workbench.colorCustomizations": {},
  "workbench.settings.editor": "json",

  // Error Lens
  "errorLens.enabledDiagnosticLevels": ["error", "warning", "info"],
  "errorLens.excludeBySource": ["cSpell"],

  // Auto Import
  "typescript.suggest.autoImports": true,
  "javascript.suggest.autoImports": true,
  "typescript.updateImportsOnFileMove.enabled": "always",
  "javascript.updateImportsOnFileMove.enabled": "always",

  // IntelliCode
  "vsintellicode.modify.editor.suggestSelection": "automaticallyOverrodeDefaultValue",

  // Todo Tree
  "todo-tree.general.tags": [
    "BUG",
    "HACK",
    "FIXME",
    "TODO",
    "XXX",
    "[ ]",
    "[x]"
  ],
  "todo-tree.regex.regex": "(//|#|<!--|;|/\\*|^|^\\s*(-|\\d+.))\\s*($TAGS).*(\\n|$)",

  // REST Client
  "rest-client.enableTelemetry": false,
  "rest-client.showResponseInDifferentTab": true
}
EOF

    success "Configuración settings.json creada correctamente."
}

# Función para crear keybindings personalizados
create_keybindings() {
    log "=== CREANDO KEYBINDINGS PERSONALIZADOS ==="

    local config_dir="$HOME/.config/Code/User"
    backup_config "$config_dir/keybindings.json"

    cat > "$config_dir/keybindings.json" << 'EOF'
[
  // ================================================================
  // NAVEGACIÓN RÁPIDA
  // ================================================================
  {
    "key": "ctrl+shift+e",
    "command": "workbench.view.explorer"
  },
  {
    "key": "ctrl+shift+f",
    "command": "workbench.view.search"
  },
  {
    "key": "ctrl+shift+g",
    "command": "workbench.view.scm"
  },
  {
    "key": "ctrl+shift+d",
    "command": "workbench.view.debug"
  },
  {
    "key": "ctrl+shift+x",
    "command": "workbench.view.extensions"
  },

  // ================================================================
  // BÚSQUEDA Y ARCHIVOS
  // ================================================================
  {
    "key": "ctrl+p",
    "command": "workbench.action.quickOpen"
  },
  {
    "key": "ctrl+shift+p",
    "command": "workbench.action.showCommands"
  },
  {
    "key": "ctrl+shift+o",
    "command": "workbench.action.gotoSymbol"
  },
  {
    "key": "ctrl+t",
    "command": "workbench.action.showAllSymbols"
  },

  // ================================================================
  // EDICIÓN AVANZADA
  // ================================================================
  {
    "key": "alt+up",
    "command": "editor.action.moveLinesUpAction",
    "when": "editorTextFocus && !editorReadonly"
  },
  {
    "key": "alt+down",
    "command": "editor.action.moveLinesDownAction",
    "when": "editorTextFocus && !editorReadonly"
  },
  {
    "key": "shift+alt+up",
    "command": "editor.action.copyLinesUpAction",
    "when": "editorTextFocus && !editorReadonly"
  },
  {
    "key": "shift+alt+down",
    "command": "editor.action.copyLinesDownAction",
    "when": "editorTextFocus && !editorReadonly"
  },
  {
    "key": "ctrl+d",
    "command": "editor.action.addSelectionToNextFindMatch",
    "when": "editorFocus"
  },
  {
    "key": "ctrl+k ctrl+d",
    "command": "editor.action.moveSelectionToNextFindMatch",
    "when": "editorFocus"
  },

  // ================================================================
  // FORMATEO Y ORGANIZACIÓN
  // ================================================================
  {
    "key": "shift+alt+f",
    "command": "editor.action.formatDocument",
    "when": "editorHasDocumentFormattingProvider && editorTextFocus && !editorReadonly"
  },
  {
    "key": "ctrl+k ctrl+f",
    "command": "editor.action.formatSelection",
    "when": "editorHasDocumentSelectionFormattingProvider && editorTextFocus && !editorReadonly"
  },
  {
    "key": "shift+alt+o",
    "command": "editor.action.organizeImports",
    "when": "editorTextFocus && !editorReadonly"
  },

  // ================================================================
  // TERMINAL
  // ================================================================
  {
    "key": "ctrl+`",
    "command": "workbench.action.terminal.toggleTerminal"
  },
  {
    "key": "ctrl+shift+`",
    "command": "workbench.action.terminal.new"
  },

  // ================================================================
  // GIT
  // ================================================================
  {
    "key": "ctrl+shift+g g",
    "command": "git.openChange"
  },
  {
    "key": "ctrl+shift+g s",
    "command": "git.stage"
  },
  {
    "key": "ctrl+shift+g u",
    "command": "git.unstage"
  },
  {
    "key": "ctrl+shift+g c",
    "command": "git.commit"
  },
  {
    "key": "ctrl+shift+g p",
    "command": "git.push"
  },
  {
    "key": "ctrl+shift+g l",
    "command": "git.pull"
  },

  // ================================================================
  // GITHUB COPILOT
  // ================================================================
  {
    "key": "ctrl+enter",
    "command": "github.copilot.generate",
    "when": "editorTextFocus && github.copilot.activated"
  },
  {
    "key": "alt+]",
    "command": "github.copilot.nextInlineSuggestion",
    "when": "editorTextFocus && github.copilot.activated"
  },
  {
    "key": "alt+[",
    "command": "github.copilot.previousInlineSuggestion",
    "when": "editorTextFocus && github.copilot.activated"
  },

  // ================================================================
  // NAVEGACIÓN DE CÓDIGO
  // ================================================================
  {
    "key": "f12",
    "command": "editor.action.revealDefinition",
    "when": "editorHasDefinitionProvider && editorTextFocus"
  },
  {
    "key": "alt+f12",
    "command": "editor.action.peekDefinition",
    "when": "editorHasDefinitionProvider && editorTextFocus"
  },
  {
    "key": "shift+f12",
    "command": "editor.action.goToReferences",
    "when": "editorHasReferenceProvider && editorTextFocus"
  },
  {
    "key": "f2",
    "command": "editor.action.rename",
    "when": "editorHasRenameProvider && editorTextFocus"
  },

  // ================================================================
  // UTILIDADES
  // ================================================================
  {
    "key": "ctrl+k ctrl+s",
    "command": "workbench.action.openGlobalKeybindings"
  },
  {
    "key": "ctrl+k ctrl+t",
    "command": "workbench.action.selectTheme"
  },
  {
    "key": "ctrl+k z",
    "command": "workbench.action.toggleZenMode"
  },
  {
    "key": "f11",
    "command": "workbench.action.toggleFullScreen"
  }
]
EOF

    success "Keybindings personalizados creados correctamente."
}

# Función para crear snippets personalizados
create_snippets() {
    log "=== CREANDO SNIPPETS PERSONALIZADOS ==="

    local snippets_dir="$HOME/.config/Code/User/snippets"
    mkdir -p "$snippets_dir"

    # Snippets para JavaScript/React
    cat > "$snippets_dir/javascript.json" << 'EOF'
{
  "React Functional Component": {
    "prefix": "rfc",
    "body": [
      "import React from 'react';",
      "",
      "const ${1:ComponentName} = () => {",
      "  return (",
      "    <div>",
      "      ${2:// Component content}",
      "    </div>",
      "  );",
      "};",
      "",
      "export default ${1:ComponentName};"
    ],
    "description": "Create a React functional component"
  },
  "React Component with Props": {
    "prefix": "rfcp",
    "body": [
      "import React from 'react';",
      "",
      "interface ${1:ComponentName}Props {",
      "  ${2:prop}: ${3:string};",
      "}",
      "",
      "const ${1:ComponentName}: React.FC<${1:ComponentName}Props> = ({ ${2:prop} }) => {",
      "  return (",
      "    <div>",
      "      ${4:// Component content}",
      "    </div>",
      "  );",
      "};",
      "",
      "export default ${1:ComponentName};"
    ],
    "description": "Create a React functional component with props"
  },
  "useState Hook": {
    "prefix": "us",
    "body": [
      "const [${1:state}, set${1/(.)/\u$1/}] = useState(${2:initialValue});"
    ],
    "description": "useState hook"
  },
  "useEffect Hook": {
    "prefix": "ue",
    "body": [
      "useEffect(() => {",
      "  ${1:// Effect logic}",
      "}, [${2:dependencies}]);"
    ],
    "description": "useEffect hook"
  },
  "Console Log": {
    "prefix": "cl",
    "body": [
      "console.log(${1:'${2:message}', }$0);"
    ],
    "description": "Console log statement"
  },
  "Arrow Function": {
    "prefix": "af",
    "body": [
      "const ${1:functionName} = (${2:params}) => {",
      "  ${3:// Function body}",
      "};"
    ],
    "description": "Arrow function"
  },
  "Try Catch Block": {
    "prefix": "try",
    "body": [
      "try {",
      "  ${1:// Try block}",
      "} catch (${2:error}) {",
      "  ${3:console.error(error);}",
      "}"
    ],
    "description": "Try catch block"
  }
}
EOF

    # Snippets para TypeScript
    cat > "$snippets_dir/typescript.json" << 'EOF'
{
  "Interface": {
    "prefix": "int",
    "body": [
      "interface ${1:InterfaceName} {",
      "  ${2:property}: ${3:string};",
      "}"
    ],
    "description": "TypeScript interface"
  },
  "Type": {
    "prefix": "type",
    "body": [
      "type ${1:TypeName} = {",
      "  ${2:property}: ${3:string};",
      "};"
    ],
    "description": "TypeScript type"
  },
  "Enum": {
    "prefix": "enum",
    "body": [
      "enum ${1:EnumName} {",
      "  ${2:VALUE1} = '${3:value1}',",
      "  ${4:VALUE2} = '${5:value2}',",
      "}"
    ],
    "description": "TypeScript enum"
  }
}
EOF

    # Snippets para PHP
    cat > "$snippets_dir/php.json" << 'EOF'
{
  "PHP Class": {
    "prefix": "class",
    "body": [
      "<?php",
      "",
      "class ${1:ClassName}",
      "{",
      "    ${2:// Class content}",
      "}"
    ],
    "description": "PHP class"
  },
  "PHP Function": {
    "prefix": "func",
    "body": [
      "public function ${1:functionName}(${2:$parameters})",
      "{",
      "    ${3:// Function content}",
      "}"
    ],
    "description": "PHP function"
  },
  "PHP Constructor": {
    "prefix": "construct",
    "body": [
      "public function __construct(${1:$parameters})",
      "{",
      "    ${2:// Constructor content}",
      "}"
    ],
    "description": "PHP constructor"
  },
  "PHP Array": {
    "prefix": "arr",
    "body": [
      "$${1:arrayName} = [",
      "    ${2:'key' => 'value',}",
      "];"
    ],
    "description": "PHP array"
  }
}
EOF

    # Snippets para Python
    cat > "$snippets_dir/python.json" << 'EOF'
{
  "Python Class": {
    "prefix": "class",
    "body": [
      "class ${1:ClassName}:",
      "    def __init__(self${2:, parameters}):",
      "        ${3:pass}"
    ],
    "description": "Python class"
  },
  "Python Function": {
    "prefix": "def",
    "body": [
      "def ${1:function_name}(${2:parameters}):",
      "    ${3:pass}"
    ],
    "description": "Python function"
  },
  "Python Main": {
    "prefix": "main",
    "body": [
      "if __name__ == '__main__':",
      "    ${1:main()}"
    ],
    "description": "Python main"
  },
  "Python Import": {
    "prefix": "imp",
    "body": [
      "import ${1:module}"
    ],
    "description": "Python import"
  },
  "Python From Import": {
    "prefix": "from",
    "body": [
      "from ${1:module} import ${2:function}"
    ],
    "description": "Python from import"
  }
}
EOF

    success "Snippets personalizados creados correctamente."
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
        log "Abriendo VS Code para configurar Copilot..."
        code --new-window
        echo ""
        info "Pasos para configurar Copilot en VS Code:"
        echo "1. Presiona Ctrl+Shift+P"
        echo "2. Escribe: GitHub Copilot: Sign In"
        echo "3. Sigue las instrucciones para autenticarte"
        echo "4. Reinicia VS Code después de la autenticación"
        echo ""
        warning "Después de configurar Copilot, reinicia VS Code."
    else
        info "Puedes configurar Copilot más tarde:"
        echo "1. Abre VS Code"
        echo "2. Presiona Ctrl+Shift+P"
        echo "3. Escribe: GitHub Copilot: Sign In"
    fi
}

# Función para instalar fuentes adicionales
install_fonts() {
    log "=== INSTALANDO FUENTES PARA DESARROLLO ==="

    local fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"

    # Instalar Fira Code
    if [[ ! -f "$fonts_dir/FiraCode-Regular.ttf" ]]; then
        log "Instalando Fira Code..."
        wget -q "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip" -O /tmp/fira_code.zip
        unzip -q /tmp/fira_code.zip -d /tmp/fira_code
        cp /tmp/fira_code/ttf/*.ttf "$fonts_dir/"
        rm -rf /tmp/fira_code /tmp/fira_code.zip
    fi

    # Instalar JetBrains Mono
    if [[ ! -f "$fonts_dir/JetBrainsMono-Regular.ttf" ]]; then
        log "Instalando JetBrains Mono..."
        wget -q "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" -O /tmp/jetbrains_mono.zip
        unzip -q /tmp/jetbrains_mono.zip -d /tmp/jetbrains_mono
        cp /tmp/jetbrains_mono/fonts/ttf/*.ttf "$fonts_dir/"
        rm -rf /tmp/jetbrains_mono /tmp/jetbrains_mono.zip
    fi

    # Actualizar cache de fuentes
    fc-cache -f -v > /dev/null 2>&1

    success "Fuentes instaladas correctamente."
}

# Función para verificar instalación
verify_installation() {
    log "=== VERIFICANDO INSTALACIÓN ==="

    info "Verificando componentes instalados:"

    # Verificar VS Code
    if command -v code &> /dev/null; then
        success "✓ VS Code: $(code --version | head -1)"
    else
        error "✗ VS Code no está instalado"
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

    # Verificar configuraciones
    local config_dir="$HOME/.config/Code/User"
    if [[ -f "$config_dir/settings.json" ]]; then
        success "✓ settings.json configurado"
    else
        error "✗ settings.json no está configurado"
    fi

    if [[ -f "$config_dir/keybindings.json" ]]; then
        success "✓ keybindings.json configurado"
    else
        error "✗ keybindings.json no está configurado"
    fi

    # Contar extensiones instaladas
    local extensions_count=$(code --list-extensions | wc -l)
    if [[ $extensions_count -gt 0 ]]; then
        success "✓ $extensions_count extensiones instaladas"
    else
        warning "✗ No hay extensiones instaladas"
    fi
}

# Función para mostrar guía de uso
show_usage_guide() {
    log "=== GUÍA DE USO RÁPIDO ==="

    echo -e "${CYAN}"
    cat << 'EOF'
🚀 ATAJOS DE TECLADO PRINCIPALES VS CODE

=== NAVEGACIÓN ===
Ctrl+Shift+E      - Explorador de archivos
Ctrl+Shift+F      - Búsqueda global
Ctrl+Shift+G      - Control de versiones (Git)
Ctrl+P            - Búsqueda rápida de archivos
Ctrl+Shift+P      - Paleta de comandos

=== EDICIÓN ===
Alt+↑/↓           - Mover línea arriba/abajo
Shift+Alt+↑/↓     - Duplicar línea arriba/abajo
Ctrl+D            - Seleccionar siguiente coincidencia
Shift+Alt+F       - Formatear documento
F2                - Renombrar símbolo

=== AUTOCOMPLETADO ===
Ctrl+Space        - Activar IntelliSense
Tab               - Aceptar sugerencia
Ctrl+Enter        - Activar GitHub Copilot
Alt+]/[           - Navegar sugerencias Copilot

=== GIT ===
Ctrl+Shift+G G    - Ver cambios
Ctrl+Shift+G S    - Agregar al stage
Ctrl+Shift+G C    - Commit
Ctrl+Shift+G P    - Push

=== TERMINAL ===
Ctrl+`            - Toggle terminal
Ctrl+Shift+`      - Nuevo terminal

=== NAVEGACIÓN DE CÓDIGO ===
F12               - Ir a definición
Alt+F12           - Peek definición
Shift+F12         - Buscar referencias
Ctrl+T            - Buscar símbolos

=== UTILIDADES ===
F11               - Pantalla completa
Ctrl+K Z          - Modo Zen
Ctrl+K Ctrl+T     - Cambiar tema

EOF
    echo -e "${NC}"

    info "Extensiones principales instaladas:"
    echo "• GitHub Copilot - Autocompletado con IA"
    echo "• Prettier - Formateo automático"
    echo "• ESLint - Linting JavaScript/TypeScript"
    echo "• PHP Intelephense - Autocompletado PHP"
    echo "• Python - Soporte completo para Python"
    echo "• GitLens - Git avanzado"
    echo "• Live Server - Servidor de desarrollo"
    echo "• Markdown All in One - Soporte Markdown"
}

# Función principal
main() {
    check_user

    log "🚀 Configuración VS Code Profesional para Desarrollo Full Stack"
    log "Este script configurará VS Code con extensiones para PHP, React, Next.js, Python, TypeScript, JavaScript y Markdown"

    echo -e "${YELLOW}"
    echo "¿Qué componentes deseas instalar?"
    echo "1) Instalación completa (recomendado)"
    echo "2) Solo dependencias del sistema"
    echo "3) Solo VS Code"
    echo "4) Solo extensiones"
    echo "5) Solo configuración"
    echo "6) Solo GitHub Copilot"
    echo "7) Solo fuentes"
    echo "8) Personalizado"
    echo -e "${NC}"

    read -p "Selecciona una opción (1-8): " choice

    case $choice in
        1)
            install_system_dependencies
            install_vscode
            install_extensions
            create_settings
            create_keybindings
            create_snippets
            install_fonts
            setup_copilot
            ;;
        2)
            install_system_dependencies
            ;;
        3)
            install_vscode
            ;;
        4)
            install_extensions
            ;;
        5)
            create_settings
            create_keybindings
            create_snippets
            ;;
        6)
            setup_copilot
            ;;
        7)
            install_fonts
            ;;
        8)
            echo "Selecciona los componentes a instalar:"
            read -p "¿Instalar dependencias del sistema? (y/n): " opt_deps
            read -p "¿Instalar VS Code? (y/n): " opt_vscode
            read -p "¿Instalar extensiones? (y/n): " opt_extensions
            read -p "¿Crear configuraciones? (y/n): " opt_settings
            read -p "¿Instalar fuentes? (y/n): " opt_fonts
            read -p "¿Configurar Copilot? (y/n): " opt_copilot

            [[ "$opt_deps" == "y" ]] && install_system_dependencies
            [[ "$opt_vscode" == "y" ]] && install_vscode
            [[ "$opt_extensions" == "y" ]] && install_extensions
            [[ "$opt_settings" == "y" ]] && create_settings && create_keybindings && create_snippets
            [[ "$opt_fonts" == "y" ]] && install_fonts
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
    success "🎉 VS Code está listo para desarrollo profesional!"

    warning "NOTAS IMPORTANTES:"
    echo "• Reinicia VS Code para aplicar todas las configuraciones"
    echo "• Para GitHub Copilot, usa Ctrl+Shift+P y busca 'GitHub Copilot: Sign In'"
    echo "• Las fuentes se aplicarán después de reiniciar VS Code"
    echo "• Usa Ctrl+Shift+P para acceder a la paleta de comandos"

    info "¡Disfruta programando con tu nuevo entorno VS Code profesional! 🚀"
}

# Ejecutar función principal
main "$@"
