#!/usr/bin/env bash
set -euo pipefail

# Script para configurar Git globalmente
# - Define usuario y correo
# - Establece aliases comunes
# - Aplica recomendaciones de rendimiento y seguridad

# Datos de usuario
git config --global user.email "lgzarturo@gmail.com"
# Reemplaza con tu nombre completo
git config --global user.name "Arturo López Gómez"

# Editor por defecto para mensajes de commit
git config --global core.editor "code --wait"

# Colores en salida
git config --global color.ui auto

enable_experimental="true"

# Manejo de credenciales (cache por 1 hora)
git config --global credential.helper "cache --timeout=3600"

# Push default
git config --global push.default simple

# Enable rerere to reuse recorded resolutions
git config --global rerere.enabled true

# Rebase interactivo por defecto al pull
git config --global pull.rebase true

# Aliases más cómodos
git config --global alias.st "status"
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.cm "commit -m"
git config --global alias.ca "commit --amend --no-edit"
git config --global alias.df "diff"
git config --global alias.dc "diff --cached"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.lg2 "log --graph --decorate --pretty=oneline --abbrev-commit"
git config --global alias.unstage "reset HEAD --"
git config --global alias.last "log -1 HEAD"

# Mejora de rendimiento: ajusta delta para grandes repositorios
git config --global core.deltaBaseCacheLimit "2g"

# Ignorar permisos de archivos
git config --global core.fileMode false

# Mensaje final
echo "Configuración de Git completada exitosamente."

