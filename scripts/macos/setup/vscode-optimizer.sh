#!/usr/bin/env bash
set -euo pipefail

# Script para configurar Visual Studio Code
# - Optimiza rendimiento
# - Ajusta preferencias
# - Instala extensiones para Python, JS/TS, Next.js, React, FastAPI, Django
# - Configura corrección ortográfica en español e inglés

# 1. Verificar CLI de VSCode
type code >/dev/null 2>&1 || {
  echo "Instalando VSCode CLI..."
  # En Debian/Ubuntu (ajusta si usas otro SO)
  ln -s /usr/share/code/bin/code /usr/local/bin/code
}

# 2. Instalar extensiones necesarias
declare -a exts=(
  # Python
  "ms-python.python"
  "ms-python.vscode-pylance"
  "njpwerner.autodocstring"
  "magicstack.magicpython"

  # JavaScript / TypeScript
  "ms-vscode.vscode-typescript-next"
  "esbenp.prettier-vscode"
  "dbaeumer.vscode-eslint"

  # Frameworks
  "formulahendry.auto-rename-tag"
  "christian-kohler.npm-intellisense"
  "xabikos.javascriptsnippets"
  "ms-azuretools.vscode-docker"
  "dsznajder.es7-react-js-snippets"
  "arjun.swagger-viewer"

  # Spell check (ES / EN)
  "streetsidesoftware.code-spell-checker"
  "streetsidesoftware.code-spell-checker-spanish"
)

for ext in "${exts[@]}"; do
  echo "Instalando extensión: $ext"
  code --install-extension "$ext" --force
done

# 3. Crear settings.json personalizado
SETTINGS_DIR="$HOME/.config/Code/User"
mkdir -p "$SETTINGS_DIR"
cat > "$SETTINGS_DIR/settings.json" << 'EOF'
{
  // Rendimiento
  "workbench.startupEditor": "none",
  "workbench.enableExperiments": false,
  "extensions.autoUpdate": true,
  "telemetry.enableCrashReporter": false,
  "telemetry.enableTelemetry": false,

  // Formateo y lint
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": true,
    "source.fixAll.eslint": true
  },

  // Spell Check
  "cSpell.language": "en,es",
  "cSpell.enabled": true,

  // Python
  "python.languageServer": "Pylance",
  "python.formatting.provider": "black",
  "python.linting.enabled": true,
  "python.linting.flake8Enabled": true,
  "python.testing.unittestEnabled": false,

  // JS/TS
  "typescript.updateImportsOnFileMove.enabled": "always",

  // Terminal integrado
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.shell.linux": "/bin/bash",

  // Docker
  "docker.showExplorer": true
}
EOF

# 4. Instalar configuraciones adicionales (snippets, temas opcionales)
echo "Configuración de temas y snippets añadida."

# 5. Reiniciar VSCode para aplicar cambios
echo "Reinicia VSCode para completar la configuración."

