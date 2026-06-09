#!/usr/bin/env bash
set -e

tools=(k9s krew kube-ps1 kubespy fzf gh bat rg lazygit yq just)

echo "Verificando e instalando herramientas..."

# Instalar Homebrew si no está presente
if ! command -v brew &>/dev/null; then
  echo "Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

for tool in "${tools[@]}"; do
  if ! command -v "${tool}" &>/dev/null; then
    echo "Instalando ${tool}..."
    brew install "${tool}"
  else
    echo "${tool} ya está instalado, omitiendo..."
  fi
done

echo "Configurando fzf integración en shell..."
# Completado e bindings
$(brew --prefix)/opt/fzf/install --all --no-update-rc

kubectl krew install tree
kubectl krew install ai
kubectl krew install tunnel

echo "¡Instalación completada!"

cat <<'EOF'

Guía rápida de uso:

k9s             – UI en terminal para explorar clusters Kubernetes, cambiar contexto/namespaces, ver logs en tiempo real. Usa `k9s -n <namespace>` o '?' dentro del UI para ayuda.  [oai_citation:0‡Automation Admin](https://automationadmin.com/2022/07/kubectl-k9s?utm_source=chatgpt.com) [oai_citation:1‡Baeldung on Kotlin](https://www.baeldung.com/ops/k9s-kubernetes-cluster-management?utm_source=chatgpt.com)

kubectl-tree   – Muestra recursos de Kubernetes en estructura de árbol (nodo -> pods -> etc.). Ayuda para entender relaciones rápidamente.

kube-ps1       – Muestra contexto y namespace activo en tu prompt del shell, útil para siempre saber dónde estás trabajando.  [oai_citation:2‡K9s](https://k9scli.io/topics/install/?utm_source=chatgpt.com)

kubespy       – Observa cambios en recursos Kubernetes en tiempo real (ideal para debugging).

kubectl-doctor – Escanea tu cluster y reporta anomalías o configuraciones problemáticas (como "brew doctor" para Kubernetes).  [oai_citation:3‡K9s](https://k9scli.io/topics/install/?utm_source=chatgpt.com)

ktunnel       – Crea túneles inversos entre tu máquina y cluster K8s, ideal para acceder a servicios internos desde local.

fzf           – Selector fuzzy interactivo para buscar archivos, historial, procesos, etc. Muy útil combinado con otros comandos.  [oai_citation:4‡junegunn.choi.](https://junegunn.github.io/fzf/installation/?utm_source=chatgpt.com) [oai_citation:5‡Sourabh](https://sourabhbajaj.com/mac-setup/iTerm/fzf.html?utm_source=chatgpt.com)

gh            – CLI oficial de GitHub: crea issues, PRs, revisa repos, directamente desde terminal.

bat           – Alternativa a `cat` con resaltado de sintaxis y paginación (ideal para leer manifiestos YAML, código).

ripgrep (rg)  – Búsqueda ultra-rápida en archivos fuente, más eficiente que `grep`.

lazygit       – UI tipo TUI para manejar repos Git desde terminal: staging, diffs, commits de forma visual.

yq            – Herramienta para procesar archivos YAML con sintaxis tipo `jq`: lectura, modificación, transformación.

just          – Ejecuta recetas de comandos (tipo Make, pero más simple). Ideal para automatizar tareas comunes del proyecto.

EOF

echo "🔧 Actualizando ~/.zshrc..."

ZSHRC="$HOME/.zshrc"
TMP="${ZSHRC}.tmp"

# Añadir plugins y configuraciones si no existen ya
grep -q "plugins=.*kubectl" "$ZSHRC" || sed -E "/^plugins=\(/ s/\)/ kubectl kube-ps1)/" "$ZSHRC" > "$TMP" && mv "$TMP" "$ZSHRC"
grep -q "source <\(\fzf --zsh\)" "$ZSHRC" || echo "source <(fzf --zsh)" >> "$ZSHRC"
grep -q "source <\(kubectl completion zsh\)" "$ZSHRC" || echo "source <(kubectl completion zsh)" >> "$ZSHRC"
grep -q "PROMPT=.*\\\$\(kube_ps1\\\)" "$ZSHRC" || echo "PROMPT='$(kube_ps1)'\$PROMPT" >> "$ZSHRC"

# Agregar aliases de kubectl
cat << 'EOF' >> "$ZSHRC"

# Aliases útiles para kubectl
alias kg='kubectl get'
alias kgpo='kubectl get pods'
alias klo='kubectl logs -f'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias kdp='kubectl describe pods'
EOF

# Agregar funciones con fzf para kubectl
cat << 'EOF' >> "$ZSHRC"

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
EOF

# Ejemplo Justfile en el proyecto
cat << 'EOF' > Justfile.example
# Justfile de ejemplo

# Receta básica
hello:
	echo "Hola desde Just!"

# Alias en Just
alias r := hello

# Dependencias entre recetas
build: clean
	echo "Construyendo..."

clean:
	echo "Limpiando..."

# Selección interactiva con fzf
run: hello

EOF
echo "Creado ejemplo de Justfile: Justfile.example"
echo "Recarga tu terminal con: source ~/.zshrc"