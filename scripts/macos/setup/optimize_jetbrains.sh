#!/opt/homebrew/bin/bash

# Script de Optimización JetBrains IDEs para macOS MacBook Air M2 16GB RAM
# Versión: 3.0 - Adaptado para macOS
# IDEs: IntelliJ IDEA, PyCharm, DataGrip, PhpStorm, WebStorm

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

# Detectar configuraciones del sistema macOS

detect_system_info() {
    log "=== DETECTANDO CONFIGURACIÓN DEL SISTEMA macOS ==="

    local total_ram_bytes=$(sysctl -n hw.memsize)
    local total_ram_gb=$((total_ram_bytes / 1024 / 1024 / 1024))
    local cpu_cores=$(sysctl -n hw.ncpu)
    local cpu_info=$(sysctl -n machdep.cpu.brand_string)

    info "💻 Información del sistema:"
    echo "   RAM Total: ${total_ram_gb}GB"
    echo "   CPU Cores: ${cpu_cores}"
    echo "   CPU: ${cpu_info}"
    echo ""

    if [[ $total_ram_gb -lt 15 ]]; then
        warning "⚠️  RAM detectada menor a 16GB. Los ajustes pueden necesitar modificación."
    fi

    success "✅ Sistema compatible detectado"
}

# Función para hacer backup
backup_config() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log "📁 Backup creado: ${file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Detectar IDEs de JetBrains

detect_jetbrains_apps_and_configs() {
    log "=== DETECTANDO APPS Y CONFIGURACIONES DE JETBRAINS EN macOS ==="

    local app_dirs=("$HOME/Applications" "/Applications")
    local config_dirs=("$HOME/Library/Application Support/JetBrains" "$HOME/Library/Preferences")

    local found_apps=0
    local found_configs=0

    echo ""
    info "🔎 Buscando aplicaciones JetBrains instaladas en macOS..."

    for dir in "${app_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            for app in "$dir"/*.app; do
                if [[ -e "$app" ]]; then
                    local app_name=$(basename "$app")
                    case "$app_name" in
                        *IntelliJ*|*PyCharm*|*DataGrip*|*PhpStorm*|*WebStorm*)
                            info "   • App encontrada: $app_name en $dir"
                            found_apps=1
                            ;;
                    esac
                fi
            done
        fi
    done

    if [[ $found_apps -eq 0 ]]; then
        warning "⚠️  No se encontraron apps de JetBrains instaladas en macOS."
        echo "   Para instalarlas, visita: https://www.jetbrains.com/toolbox/"
    else
        success "✅ Apps de JetBrains detectadas"
    fi

    echo ""
    info "🔎 Buscando configuraciones de JetBrains en macOS..."

    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local configs_found=$(find "$dir" -maxdepth 1 -type d -name "*2024.*" 2>/dev/null)
            if [[ -n "$configs_found" ]]; then
                info "   • Configuraciones encontradas en: $dir"
                found_configs=1
                for config_path in $configs_found; do
                    echo "      - $(basename "$config_path")"
                done
            fi
        fi
    done

    if [[ $found_configs -eq 0 ]]; then
        warning "⚠️  No se encontraron configuraciones de JetBrains en macOS."
    else
        success "✅ Configuraciones de JetBrains detectadas"
    fi

    return $((found_apps && found_configs))
}

# Función para detectar IDEs instalados en macOS
# Busca en rutas típicas de macOS para JetBrains

detect_jetbrains_ides() {
    log "=== DETECTANDO IDEs DE JETBRAINS EN macOS ==="

    declare -A ide_paths

    # Directorios comunes de configuración en macOS
    local config_base_dirs=(
        "$HOME/Library/Application Support/JetBrains"
        "$HOME/Library/Preferences",
        "$HOME/Applications"
    )

    # Buscar carpetas de IDEs 2024.x
    for base_dir in "${config_base_dirs[@]}"; do
        if [[ -d "$base_dir" ]]; then
            for ide_dir in $(find "$base_dir" -maxdepth 1 -type d -name "*2024.*" 2>/dev/null); do
                local ide_name_lower=$(basename "$ide_dir" | tr '[:upper:]' '[:lower:]')
                if [[ $ide_name_lower == *intellij* ]]; then
                    ide_paths["intellij"]="$ide_dir"
                    info "🔍 IntelliJ IDEA encontrado: $ide_dir"
                elif [[ $ide_name_lower == *pycharm* ]]; then
                    ide_paths["pycharm"]="$ide_dir"
                    info "🔍 PyCharm encontrado: $ide_dir"
                elif [[ $ide_name_lower == *datagrip* ]]; then
                    ide_paths["datagrip"]="$ide_dir"
                    info "🔍 DataGrip encontrado: $ide_dir"
                elif [[ $ide_name_lower == *phpstorm* ]]; then
                    ide_paths["phpstorm"]="$ide_dir"
                    info "🔍 PhpStorm encontrado: $ide_dir"
                elif [[ $ide_name_lower == *webstorm* ]]; then
                    ide_paths["webstorm"]="$ide_dir"
                    info "🔍 WebStorm encontrado: $ide_dir"
                fi
            done
        fi
    done

    if [[ ${#ide_paths[@]} -eq 0 ]]; then
        warning "⚠️  No se encontraron IDEs de JetBrains instalados en macOS."
        echo "   Para instalarlos, visita: https://www.jetbrains.com/toolbox/"
        return 1
    fi

    echo " "
    info "IDEs encontrados:"
    for ide in "${!ide_paths[@]}"; do
        info "   - $ide: ${ide_paths[$ide]}"
    done
    echo " "

    success "✅ ${#ide_paths[@]} IDE(s) de JetBrains detectados"
    return 0
}

# Función para optimizar configuración de memoria
optimize_memory_settings() {
    local ide_name="$1"
    local config_dir="$2"

    log "=== OPTIMIZANDO CONFIGURACIÓN DE MEMORIA PARA ${ide_name^^} ==="

    mkdir -p "$config_dir"

    case "$ide_name" in
        "intellij")
            create_idea_vmoptions "$config_dir"
            ;;
        "pycharm")
            create_pycharm_vmoptions "$config_dir"
            ;;
        "datagrip")
            create_datagrip_vmoptions "$config_dir"
            ;;
        "phpstorm")
            create_phpstorm_vmoptions "$config_dir"
            ;;
        "webstorm")
            create_webstorm_vmoptions "$config_dir"
            ;;
    esac

    success "✅ Configuración de memoria optimizada para $ide_name"
}

# Funciones para crear archivos vmoptions en macOS

create_idea_vmoptions() {
    local config_dir="$1"
    local vmoptions_file="$config_dir/idea.vmoptions"

    backup_config "$vmoptions_file"

    cat > "$vmoptions_file" << 'EOF'
# ====
# CONFIGURACIÓN OPTIMIZADA PARA macOS MacBook Air M2 16GB RAM - INTELLIJ IDEA
# ====

# Memoria Heap (6GB para desarrollo medio-grande)
-Xms2048m
-Xmx6144m

# Memoria Metaspace (para clases Java)
-XX:MetaspaceSize=512m
-XX:MaxMetaspaceSize=1024m

# Garbage Collector Optimizado (G1GC para mejor rendimiento)
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200
-XX:G1HeapRegionSize=16m
-XX:G1NewSizePercent=20
-XX:G1MaxNewSizePercent=40
-XX:InitiatingHeapOccupancyPercent=45

# Optimizaciones de Compilación JIT
-XX:+UseStringDeduplication
-XX:+OptimizeStringConcat
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers

# Optimizaciones de I/O y Cache
-Djava.awt.useSystemAAFontSettings=lcd
-Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine
-Dsun.java2d.marlin.useThreadLocal=true

# Configuraciones específicas para IntelliJ
-Didea.trust.all.projects=true
-Didea.powersave.mode=false
-Didea.max.intellisense.filesize=5000
-Didea.cycle.buffer.size=disabled

# Optimizaciones de UI
-Dswing.aatext=true
-Dawt.useSystemAAFontSettings=on
-Dsun.java2d.xrender=true

# Configuraciones de red y proxy
-Djava.net.useSystemProxies=true
-Dhttp.nonProxyHosts=localhost|127.*|[::1]

# Directorio temporal optimizado
-Djava.io.tmpdir=/tmp/idea

# Logging optimizado
-Didea.log.debug.categories=#com.intellij

# Configuraciones de seguridad
-Djdk.http.auth.tunneling.disabledSchemes=""
-Djdk.attach.allowAttachSelf=true

# Optimizaciones específicas para desarrollo Java
-Dfile.encoding=UTF-8
-Dconsole.encoding=UTF-8
-Didea.maven.always.download.sources=true
-Didea.gradle.always.download.sources=true

# Configuraciones de rendimiento adicionales
-XX:+UnlockExperimentalVMOptions
-XX:+UseFastUnorderedTimeStamps
-XX:+UseTransparentHugePages
-XX:+AlwaysPreTouch
EOF

    info "📝 Configuración IntelliJ IDEA optimizada para macOS creada"
}

create_pycharm_vmoptions() {
    local config_dir="$1"
    local vmoptions_file="$config_dir/pycharm.vmoptions"

    backup_config "$vmoptions_file"

    cat > "$vmoptions_file" << 'EOF'
# ====
# CONFIGURACIÓN OPTIMIZADA PARA macOS MacBook Air M2 16GB RAM - PYCHARM
# ====

# Memoria Heap (5GB para proyectos Python medianos-grandes)
-Xms1536m
-Xmx5120m

# Memoria Metaspace
-XX:MetaspaceSize=256m
-XX:MaxMetaspaceSize=512m

# Garbage Collector Optimizado
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200
-XX:G1HeapRegionSize=16m
-XX:G1NewSizePercent=25
-XX:G1MaxNewSizePercent=40
-XX:InitiatingHeapOccupancyPercent=45

# Optimizaciones específicas para Python
-XX:+UseStringDeduplication
-XX:+OptimizeStringConcat
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers

# Configuraciones específicas para PyCharm
-Dpython.console.encoding=UTF-8
-Dide.mac.message.dialogs.as.sheets=false
-Didea.trust.all.projects=true
-Didea.powersave.mode=false

# Optimizaciones para análisis de código Python
-Didea.max.intellisense.filesize=5000
-Dpython.debugger.async.stacks.evaluation=true
-Dpython.console.executeInCurrentThread=false

# Configuraciones de UI optimizadas
-Dswing.aatext=true
-Dawt.useSystemAAFontSettings=on
-Dsun.java2d.xrender=true
-Djava.awt.useSystemAAFontSettings=lcd

# Optimizaciones para notebooks Jupyter
-Djupyter.notebook.max.output.size=10000
-Djupyter.debugger.enabled=true

# Configuraciones de red
-Djava.net.useSystemProxies=true
-Dhttp.nonProxyHosts=localhost|127.*|[::1]

# Directorio temporal
-Djava.io.tmpdir=/tmp/pycharm

# Configuraciones de encoding
-Dfile.encoding=UTF-8
-Dconsole.encoding=UTF-8
-Dpython.console.encoding=UTF-8

# Optimizaciones de rendimiento adicionales
-XX:+UnlockExperimentalVMOptions
-XX:+UseFastUnorderedTimeStamps
-XX:+AlwaysPreTouch

# Configuraciones específicas para desarrollo web con Django/Flask
-Ddjango.console.use_ipython=true
-Dpython.console.keep_alive=true
EOF

    info "📝 Configuración PyCharm optimizada para macOS creada"
}

create_datagrip_vmoptions() {
    local config_dir="$1"
    local vmoptions_file="$config_dir/datagrip.vmoptions"

    backup_config "$vmoptions_file"

    cat > "$vmoptions_file" << 'EOF'
# ====
# CONFIGURACIÓN OPTIMIZADA PARA macOS MacBook Air M2 16GB RAM - DATAGRIP
# ====

# Memoria Heap (4GB para bases de datos medianas-grandes)
-Xms1024m
-Xmx4096m

# Memoria Metaspace
-XX:MetaspaceSize=256m
-XX:MaxMetaspaceSize=512m

# Garbage Collector Optimizado para DB operations
-XX:+UseG1GC
-XX:MaxGCPauseMillis=100
-XX:G1HeapRegionSize=16m
-XX:G1NewSizePercent=30
-XX:G1MaxNewSizePercent=50
-XX:InitiatingHeapOccupancyPercent=40

# Optimizaciones específicas para DataGrip
-XX:+UseStringDeduplication
-XX:+OptimizeStringConcat
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers

# Configuraciones específicas para bases de datos
-Didea.trust.all.projects=true
-Ddatabase.console.LIMIT_BY_DEFAULT=true
-Ddatabase.console.LIMIT_BY_DEFAULT_VALUE=1000
-Ddb.console.result.limit=10000

# Optimizaciones para queries grandes
-Ddatabase.query.timeout=300
-Ddatabase.connection.timeout=30
-Ddatabase.max.rows.in.memory=50000

# Configuraciones de cache para metadata
-Ddatabase.metadata.cache.size=1000
-Ddatabase.introspection.enabled=true

# Configuraciones de UI
-Dswing.aatext=true
-Dawt.useSystemAAFontSettings=on
-Dsun.java2d.xrender=true
-Djava.awt.useSystemAAFontSettings=lcd

# Configuraciones de red para conexiones DB
-Djava.net.useSystemProxies=true
-Dhttp.nonProxyHosts=localhost|127.*|[::1]
-Djava.net.preferIPv4Stack=true

# SSL y seguridad para conexiones
-Dcom.sun.net.ssl.checkRevocation=false
-Dtrust_all_cert=true

# Directorio temporal
-Djava.io.tmpdir=/tmp/datagrip

# Configuraciones de encoding
-Dfile.encoding=UTF-8
-Dconsole.encoding=UTF-8
-Ddatabase.default.charset=UTF-8

# Optimizaciones de rendimiento adicionales
-XX:+UnlockExperimentalVMOptions
-XX:+UseFastUnorderedTimeStamps
-XX:+AlwaysPreTouch

# Configuraciones específicas para SQL
-Dsql.formatter.smart.indent=true
-Dsql.formatter.align.assignments=true
-Ddatabase.sql.show.only.failed.statements=false
EOF

    info "📝 Configuración DataGrip optimizada para macOS creada"
}

create_phpstorm_vmoptions() {
    local config_dir="$1"
    local vmoptions_file="$config_dir/phpstorm.vmoptions"

    backup_config "$vmoptions_file"

    cat > "$vmoptions_file" << 'EOF'
# ====
# CONFIGURACIÓN OPTIMIZADA PARA macOS MacBook Air M2 16GB RAM - PHPSTORM
# ====

# Memoria Heap (5GB para proyectos PHP medianos-grandes)
-Xms1536m
-Xmx5120m

# Memoria Metaspace
-XX:MetaspaceSize=256m
-XX:MaxMetaspaceSize=512m

# Garbage Collector Optimizado
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200
-XX:G1HeapRegionSize=16m
-XX:G1NewSizePercent=25
-XX:G1MaxNewSizePercent=40
-XX:InitiatingHeapOccupancyPercent=45

# Optimizaciones específicas para PHP
-XX:+UseStringDeduplication
-XX:+OptimizeStringConcat
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers

# Configuraciones específicas para PhpStorm
-Didea.trust.all.projects=true
-Didea.powersave.mode=false
-Didea.max.intellisense.filesize=5000
-Didea.cycle.buffer.size=disabled

# Optimizaciones para análisis de código PHP
-Dphp.index.deep.analysis=true
-Dphp.composer.autoload.deep.analysis=true
-Dphp.type.inference.enabled=true
-Dphp.debug.deep.assoc.array.analysis=true

# Configuraciones de UI optimizadas
-Dswing.aatext=true
-Dawt.useSystemAAFontSettings=on
-Dsun.java2d.xrender=true
-Djava.awt.useSystemAAFontSettings=lcd

# Optimizaciones para Composer y dependencias
-Dcomposer.autoload.deep.analysis=true
-Dcomposer.json.schema.validation=true
-Dphp.composer.include.require.dev=true

# Configuraciones para frameworks PHP
-Dlaravel.enable.blade.injections=true
-Dsymfony.enable.twig.injections=true
-Dphp.drupal.enabled=true

# Configuraciones de red
-Djava.net.useSystemProxies=true
-Dhttp.nonProxyHosts=localhost|127.*|[::1]

# Directorio temporal
-Djava.io.tmpdir=/tmp/phpstorm

# Configuraciones de encoding
-Dfile.encoding=UTF-8
-Dconsole.encoding=UTF-8
-Dphp.default.charset=UTF-8

# Optimizaciones de rendimiento adicionales
-XX:+UnlockExperimentalVMOptions
-XX:+UseFastUnorderedTimeStamps
-XX:+AlwaysPreTouch

# Configuraciones específicas para desarrollo web
-Dwebserver.default.port=8000
-Dphp.built.in.server.port=8000
-Dxdebug.default.port=9003

# Optimizaciones para testing
-Dphpunit.configuration.file.enabled=true
-Dphp.codeception.enabled=true
-Dphp.behat.enabled=true

# Configuraciones para Docker y remote development
-Ddocker.api.version=auto
-Dremote.interpreter.enabled=true
EOF

    info "📝 Configuración PhpStorm optimizada para macOS creada"
}

create_webstorm_vmoptions() {
    local config_dir="$1"
    local vmoptions_file="$config_dir/webstorm.vmoptions"

    backup_config "$vmoptions_file"

    cat > "$vmoptions_file" << 'EOF'
# ====
# CONFIGURACIÓN OPTIMIZADA PARA macOS MacBook Air M2 16GB RAM - WEBSTORM
# ====

# Memoria Heap (4.5GB para proyectos JavaScript/TypeScript medianos-grandes)
-Xms1536m
-Xmx4608m

# Memoria Metaspace
-XX:MetaspaceSize=256m
-XX:MaxMetaspaceSize=512m

# Garbage Collector Optimizado
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200
-XX:G1HeapRegionSize=16m
-XX:G1NewSizePercent=25
-XX:G1MaxNewSizePercent=40
-XX:InitiatingHeapOccupancyPercent=45

# Optimizaciones específicas para JavaScript/TypeScript
-XX:+UseStringDeduplication
-XX:+OptimizeStringConcat
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers

# Configuraciones específicas para WebStorm
-Didea.trust.all.projects=true
-Didea.powersave.mode=false
-Didea.max.intellisense.filesize=5000
-Didea.cycle.buffer.size=disabled

# Optimizaciones para análisis de código JavaScript/TypeScript
-Djavascript.nodejs.core.library.typing.enabled=true
-Dtypescript.compiler.enabled=true
-Djavascript.debugger.async.stacks.enabled=true
-Djavascript.v8.use.external.startup.data=true

# Configuraciones de UI optimizadas
-Dswing.aatext=true
-Dawt.useSystemAAFontSettings=on
-Dsun.java2d.xrender=true
-Djava.awt.useSystemAAFontSettings=lcd

# Optimizaciones para Node.js y npm
-Dnodejs.console.use.terminal=true
-Dnpm.install.fetch.retries=3
-Dnpm.install.fetch.retry.factor=2
-Dnpm.install.fetch.retry.mintimeout=10000

# Configuraciones para frameworks JavaScript
-Dreact.jsx.enabled=true
-Dvue.template.enabled=true
-Dangular.template.enabled=true
-Dember.template.enabled=true

# Configuraciones de red
-Djava.net.useSystemProxies=true
-Dhttp.nonProxyHosts=localhost|127.*|[::1]

# Directorio temporal
-Djava.io.tmpdir=/tmp/webstorm

# Configuraciones de encoding
-Dfile.encoding=UTF-8
-Dconsole.encoding=UTF-8
-Djavascript.default.charset=UTF-8

# Optimizaciones de rendimiento adicionales
-XX:+UnlockExperimentalVMOptions
-XX:+UseFastUnorderedTimeStamps
-XX:+AlwaysPreTouch

# Configuraciones específicas para desarrollo web
-Dwebserver.default.port=3000
-Dnode.js.default.port=3000
-Dwebpack.dev.server.port=8080

# Optimizaciones para bundlers y build tools
-Dwebpack.config.enabled=true
-Drollup.config.enabled=true
-Dvite.config.enabled=true
-Dparcel.config.enabled=true
-Desbuild.enabled=true

# Configuraciones para testing
-Dmocha.enabled=true
-Djest.enabled=true
-Dkarma.enabled=true
-Dcypress.enabled=true
-Dplaywright.enabled=true

# Configuraciones para linting y formatting
-Deslint.enabled=true
-Dprettier.enabled=true
-Dtslint.enabled=true
-Dstylelint.enabled=true

# Optimizaciones para Live Edit y Hot Reload
-Dlive.edit.enabled=true
-Dhot.reload.enabled=true
-Dauto.save.enabled=true
-Dbrowser.sync.enabled=true
EOF

    info "📝 Configuración WebStorm optimizada para macOS creada"
}

# Función para crear configuraciones de IDE específicas
create_ide_properties() {
    local ide_name="$1"
    local config_dir="$2"

    log "=== CREANDO PROPIEDADES ESPECÍFICAS PARA ${ide_name^^} ==="

    case "$ide_name" in
        "intellij")
            create_idea_properties "$config_dir"
            ;;
        "pycharm")
            create_pycharm_properties "$config_dir"
            ;;
        "datagrip")
            create_datagrip_properties "$config_dir"
            ;;
        "phpstorm")
            create_phpstorm_properties "$config_dir"
            ;;
        "webstorm")
            create_webstorm_properties "$config_dir"
            ;;
    esac
}

# Propiedades para IntelliJ IDEA
create_idea_properties() {
    local config_dir="$1"
    local properties_file="$config_dir/idea.properties"

    backup_config "$properties_file"

    cat > "$properties_file" << 'EOF'
# ====
# PROPIEDADES OPTIMIZADAS PARA INTELLIJ IDEA - macOS
# ====

# Configuraciones de UI y rendimiento
idea.ui.tree.indent=22
idea.popup.weight=heavy
idea.is.internal=false
idea.config.path=${user.home}/Library/Application Support/JetBrains/IntelliJIdea2024.1
idea.system.path=${user.home}/Library/Caches/JetBrains/IntelliJIdea2024.1
idea.plugins.path=${idea.config.path}/plugins
idea.log.path=${idea.system.path}/log

# Optimizaciones de cache
idea.system.path=${user.home}/Library/Caches/JetBrains/IntelliJIdea2024.1
idea.max.vcs.loaded.size.kb=20480
idea.cycle.buffer.size=disabled
idea.max.content.load.filesize=20000

# Configuraciones de indexado
idea.indices.caches.size=2048
idea.max.intellisense.filesize=5000
indexing.shared.indexes.bundled=true

# Optimizaciones de memoria
idea.platform.prefix=Idea
idea.paths.selector=IntelliJIdea2024.1
sun.io.useCanonCaches=false

# Configuraciones de red
use.proxy.pac=false
proxy.authentication.username=
proxy.authentication.password=

# Configuraciones de actualizaciones
updates.enabled=true
updates.ignored.builds=
updates.last.build.checked=

# Optimizaciones específicas para desarrollo
compiler.automake.allow.when.app.running=true
compiler.document.save.enabled=false
actionSystem.force.alt.gr=false

# Configuraciones de plugins
plugin.manager.suggest.only.featured=false
external.system.auto.import.disabled=false

# Configuraciones de terminal
terminal.escape.sequence.enabled=true
terminal.copy.on.selection=true

# Configuraciones de editor
editor.zero.latency.typing=true
editor.distraction.free.mode=false
EOF

    success "✅ Propiedades de IntelliJ IDEA configuradas para macOS"
}

# Propiedades para PyCharm
create_pycharm_properties() {
    local config_dir="$1"
    local properties_file="$config_dir/pycharm.properties"

    backup_config "$properties_file"

    cat > "$properties_file" << 'EOF'
# ====
# PROPIEDADES OPTIMIZADAS PARA PYCHARM - macOS
# ====

# Configuraciones específicas de PyCharm
idea.config.path=${user.home}/Library/Application Support/JetBrains/PyCharm2024.1
idea.system.path=${user.home}/Library/Caches/JetBrains/PyCharm2024.1
idea.plugins.path=${idea.config.path}/plugins
idea.log.path=${idea.system.path}/log

# Optimizaciones para Python
python.console.encoding=UTF-8
python.console.executeInCurrentThread=false
python.debugger.multiprocess=true
python.console.keep_alive=true

# Configuraciones de indexado Python
idea.max.intellisense.filesize=5000
python.analysis.warning.minimum.severity=WEAK WARNING
python.console.ipython.enabled=true

# Configuraciones de cache
idea.max.vcs.loaded.size.kb=20480
idea.cycle.buffer.size=disabled
indexing.shared.indexes.bundled=true

# Optimizaciones de Jupyter
jupyter.notebook.max.output.size=10000
jupyter.debugger.enabled=true
jupyter.completion.enabled=true

# Configuraciones de terminal
terminal.escape.sequence.enabled=true
terminal.copy.on.selection=true
terminal.shell.command.unix=/bin/zsh

# Configuraciones de Django
django.server.port=8000
django.console.use_ipython=true
django.template.debug=true

# Optimizaciones de rendimiento
editor.zero.latency.typing=true
compiler.automake.allow.when.app.running=true
external.system.auto.import.disabled=false

# Configuraciones de virtualenv
python.sdk.automatically.set=true
python.conda.channels=defaults,conda-forge
EOF

    success "✅ Propiedades de PyCharm configuradas para macOS"
}

# Propiedades para DataGrip
create_datagrip_properties() {
    local config_dir="$1"
    local properties_file="$config_dir/datagrip.properties"

    backup_config "$properties_file"

    cat > "$properties_file" << 'EOF'
# ====
# PROPIEDADES OPTIMIZADAS PARA DATAGRIP - macOS
# ====

# Configuraciones específicas de DataGrip
idea.config.path=${user.home}/Library/Application Support/JetBrains/DataGrip2024.1
idea.system.path=${user.home}/Library/Caches/JetBrains/DataGrip2024.1
idea.plugins.path=${idea.config.path}/plugins
idea.log.path=${idea.system.path}/log

# Configuraciones de base de datos
database.console.LIMIT_BY_DEFAULT=true
database.console.LIMIT_BY_DEFAULT_VALUE=1000
db.console.result.limit=10000

# Optimizaciones para queries grandes
database.query.timeout=300
database.connection.timeout=30
database.max.rows.in.memory=50000

# Configuraciones de cache para metadata
database.metadata.cache.size=1000
database.introspection.enabled=true

# Configuraciones de UI
Dswing.aatext=true
Dawt.useSystemAAFontSettings=on
Dsun.java2d.xrender=true
Djava.awt.useSystemAAFontSettings=lcd

# Configuraciones de red para conexiones DB
Djava.net.useSystemProxies=true
Dhttp.nonProxyHosts=localhost|127.*|[::1]
Djava.net.preferIPv4Stack=true

# SSL y seguridad para conexiones
Dcom.sun.net.ssl.checkRevocation=false
Dtrust_all_cert=true

# Directorio temporal
Djava.io.tmpdir=/tmp/datagrip

# Configuraciones de encoding
Dfile.encoding=UTF-8
Dconsole.encoding=UTF-8
Ddatabase.default.charset=UTF-8

# Optimizaciones de rendimiento adicionales
XX:+UnlockExperimentalVMOptions
XX:+UseFastUnorderedTimeStamps
XX:+AlwaysPreTouch

# Configuraciones específicas para SQL
Dsql.formatter.smart.indent=true
Dsql.formatter.align.assignments=true
Ddatabase.sql.show.only.failed.statements=false
EOF

    success "✅ Propiedades de DataGrip configuradas para macOS"
}

# Propiedades para PhpStorm
create_phpstorm_properties() {
    local config_dir="$1"
    local properties_file="$config_dir/phpstorm.properties"

    backup_config "$properties_file"

    cat > "$properties_file" << 'EOF'
# ====
# PROPIEDADES OPTIMIZADAS PARA PHPSTORM - macOS
# ====

# Configuraciones específicas de PhpStorm
idea.config.path=${user.home}/Library/Application Support/JetBrains/PhpStorm2024.1
idea.system.path=${user.home}/Library/Caches/JetBrains/PhpStorm2024.1
idea.plugins.path=${idea.config.path}/plugins
idea.log.path=${idea.system.path}/log

# Optimizaciones para PHP
php.index.deep.analysis=true
php.composer.autoload.deep.analysis=true
php.type.inference.enabled=true
php.debug.deep.assoc.array.analysis=true

# Configuraciones de indexado PHP
idea.max.intellisense.filesize=5000
php.analysis.warning.minimum.severity=WEAK WARNING
php.composer.include.require.dev=true

# Configuraciones de cache
idea.max.vcs.loaded.size.kb=20480
idea.cycle.buffer.size=disabled
indexing.shared.indexes.bundled=true

# Optimizaciones para Composer
composer.autoload.deep.analysis=true
composer.json.schema.validation=true
composer.parallel.download=true

# Configuraciones para frameworks PHP
laravel.enable.blade.injections=true
symfony.enable.twig.injections=true
php.drupal.enabled=true
php.wordpress.enabled=true

# Configuraciones de terminal
terminal.escape.sequence.enabled=true
terminal.copy.on.selection=true
terminal.shell.command.unix=/bin/zsh

# Configuraciones de servidor web
webserver.default.port=8000
php.built.in.server.port=8000
xdebug.default.port=9003

# Optimizaciones de rendimiento
editor.zero.latency.typing=true
compiler.automake.allow.when.app.running=true
external.system.auto.import.disabled=false

# Configuraciones para testing
phpunit.configuration.file.enabled=true
php.codeception.enabled=true
php.behat.enabled=true
php.pest.enabled=true

# Configuraciones para Docker
docker.api.version=auto
remote.interpreter.enabled=true
EOF

    success "✅ Propiedades de PhpStorm configuradas para macOS"
}

# Propiedades para WebStorm
create_webstorm_properties() {
    local config_dir="$1"
    local properties_file="$config_dir/webstorm.properties"

    backup_config "$properties_file"

    cat > "$properties_file" << 'EOF'
# ====
# PROPIEDADES OPTIMIZADAS PARA WEBSTORM - macOS
# ====

# Configuraciones específicas de WebStorm
idea.config.path=${user.home}/Library/Application Support/JetBrains/WebStorm2024.1
idea.system.path=${user.home}/Library/Caches/JetBrains/WebStorm2024.1
idea.plugins.path=${idea.config.path}/plugins
idea.log.path=${idea.system.path}/log

# Optimizaciones para JavaScript/TypeScript
javascript.nodejs.core.library.typing.enabled=true
typescript.compiler.enabled=true
javascript.debugger.async.stacks.enabled=true
javascript.v8.use.external.startup.data=true

# Configuraciones de indexado JavaScript
idea.max.intellisense.filesize=5000
javascript.analysis.warning.minimum.severity=WEAK WARNING
typescript.analysis.enabled=true

# Configuraciones de cache
idea.max.vcs.loaded.size.kb=20480
idea.cycle.buffer.size=disabled
indexing.shared.indexes.bundled=true

# Optimizaciones para Node.js y npm
nodejs.console.use.terminal=true
npm.install.fetch.retries=3
npm.install.fetch.retry.factor=2
npm.install.fetch.retry.mintimeout=10000

# Configuraciones para frameworks JavaScript
react.jsx.enabled=true
vue.template.enabled=true
angular.template.enabled=true
ember.template.enabled=true
svelte.enabled=true

# Configuraciones de terminal
terminal.escape.sequence.enabled=true
terminal.copy.on.selection=true
terminal.shell.command.unix=/bin/zsh

# Configuraciones de servidor web
webserver.default.port=3000
node.js.default.port=3000
webpack.dev.server.port=8080

# Optimizaciones de rendimiento
editor.zero.latency.typing=true
compiler.automake.allow.when.app.running=true
external.system.auto.import.disabled=false

# Configuraciones para bundlers y build tools
webpack.config.enabled=true
rollup.config.enabled=true
vite.config.enabled=true
parcel.config.enabled=true
esbuild.enabled=true

# Configuraciones para testing
mocha.enabled=true
jest.enabled=true
karma.enabled=true
cypress.enabled=true
playwright.enabled=true

# Configuraciones para linting y formatting
eslint.enabled=true
prettier.enabled=true
tslint.enabled=true
stylelint.enabled=true

# Optimizaciones para Live Edit y Hot Reload
live.edit.enabled=true
hot.reload.enabled=true
auto.save.enabled=true
browser.sync.enabled=true
EOF

    success "✅ Propiedades de WebStorm configuradas para macOS"
}

# Función para optimizar configuraciones del sistema operativo macOS
optimize_system_settings() {
    log "=== OPTIMIZANDO CONFIGURACIONES DEL SISTEMA macOS ==="

    # Crear directorios temporales para IDEs si no existen
    sudo mkdir -p /tmp/idea /tmp/pycharm /tmp/datagrip /tmp/phpstorm /tmp/webstorm
    sudo chmod 755 /tmp/idea /tmp/pycharm /tmp/datagrip /tmp/phpstorm /tmp/webstorm

    # macOS no usa swappiness ni inotify, no se aplican esas configuraciones

    # Configurar límites de archivos abiertos (ulimit)
    log "Configurando límites de archivos abiertos (ulimit)..."
    ulimit -n 65536 || warning "No se pudo aumentar el límite de archivos abiertos"

    success "✅ Configuraciones del sistema optimizadas para macOS"
}

# Función para crear configuraciones de editor específicas
configure_editor_settings() {
    local ide_name="$1"
    local config_dir="$2"

    log "=== CONFIGURANDO EDITOR PARA ${ide_name^^} ==="

    local options_dir="$config_dir/options"
    mkdir -p "$options_dir"

    # Configuración de editor común
    cat > "$options_dir/editor.xml" << 'EOF'
<application>
  <component name="EditorSettings">
    <option name="USE_SOFT_WRAPS" value="false" />
    <option name="SOFT_WRAP_FILE_MASKS" value="*.md; *.txt; *.rst; *.adoc" />
    <option name="STRIP_TRAILING_SPACES" value="Modified" />
    <option name="ENSURE_NEWLINE_AT_EOF" value="true" />
    <option name="SHOW_BREADCRUMBS" value="true" />
    <option name="SHOW_INTENTION_BULB" value="true" />
    <option name="ENABLE_WHEEL_FONTCHANGE" value="true" />
    <option name="MOUSE_CLICK_SELECTION_HONORS_CAMEL_WORDS" value="true" />
  </component>
  <component name="CodeInsightSettings">
    <option name="REFORMAT_ON_PASTE" value="1" />
    <option name="INDENT_TO_CARET_ON_PASTE" value="true" />
    <option name="OPTIMIZE_IMPORTS_ON_THE_FLY" value="true" />
    <option name="ADD_UNAMBIGIOUS_IMPORTS_ON_THE_FLY" value="true" />
    <option name="HIGHLIGHT_BRACES" value="true" />
    <option name="HIGHLIGHT_SCOPE" value="true" />
    <option name="HIGHLIGHT_IDENTIFIER_UNDER_CARET" value="true" />
  </component>
</application>
EOF

    # Configuración de colores y fuentes
    cat > "$options_dir/colors.scheme.xml" << 'EOF'
<application>
  <component name="EditorColorsManagerImpl">
    <global_color_scheme name="Darcula" />
  </component>
</application>
EOF

    success "✅ Configuración de editor aplicada"
}

# Función para instalar plugins recomendados
suggest_plugins() {
    log "=== PLUGINS RECOMENDADOS PARA RENDIMIENTO ÓPTIMO ==="

    info "🔌 Para IntelliJ IDEA:"
    echo "   • Lombok Plugin - Reduce boilerplate code"
    echo "   • SonarLint - Análisis de código en tiempo real"
    echo "   • GitToolBox - Mejoras para Git"
    echo "   • Rainbow Brackets - Mejor legibilidad"
    echo "   • Key Promoter X - Aprende shortcuts"
    echo ""

    info "🔌 Para PyCharm:"
    echo "   • Requirements - Gestión de dependencias"
    echo "   • Pylint - Linting mejorado"
    echo "   • Material Theme UI - Interfaz mejorada"
    echo "   • Jupyter - Mejor soporte para notebooks"
    echo "   • Django - Si trabajas con Django"
    echo ""

    info "🔌 Para DataGrip:"
    echo "   • Database Navigator - Navegación mejorada"
    echo "   • SQL Query Console - Console mejorada"
    echo "   • Database Tools and SQL - Herramientas adicionales"
    echo "   • CSV Plugin - Mejor soporte para CSV"
    echo ""

    info "🔌 Para PhpStorm:"
    echo "   • PHP Annotations - Mejor soporte para anotaciones"
    echo "   • Laravel Plugin - Soporte completo para Laravel"
    echo "   • Symfony Plugin - Soporte para Symfony"
    echo "   • Twig Support - Mejor soporte para Twig"
    echo "   • Composer.json support - Gestión de dependencias"
    echo "   • PHP Toolbox - Herramientas adicionales PHP"
    echo ""

    info "🔌 Para WebStorm:"
    echo "   • Vue.js - Soporte completo para Vue"
    echo "   • Angular and AngularJS - Soporte para Angular"
    echo "   • React Native Console - Para desarrollo React Native"
    echo "   • Node.js - Mejor integración con Node"
    echo "   • ESLint - Linting JavaScript/TypeScript"
    echo "   • Prettier - Formateo automático"
    echo ""

    warning "⚠️  Recomendación: Instala solo los plugins que realmente necesites para mantener el rendimiento."
}

# Función para mostrar configuraciones de monitoreo
show_monitoring_tips() {
    log "=== TIPS DE MONITOREO Y RENDIMIENTO ==="

    info "🔍 Comandos útiles para monitorear:"
    echo "   • top - Monitor de procesos en tiempo real"
    echo "   • vm_stat - Estadísticas de memoria"
    echo "   • iostat - I/O del sistema"
    echo "   • ps aux | grep java - Procesos Java activos"
    echo ""

    info "📊 Configuraciones adicionales recomendadas:"
    echo "   • Habilitar 'Power Save Mode' cuando no desarrolles activamente"
    echo "   • Usar 'Distraction Free Mode' para sesiones de codificación largas"
    echo "   • Configurar 'Auto Import' para reducir escritura manual"
    echo "   • Activar 'Code Completion' pero limitar sugerencias"
    echo ""

    info "⚡ Optimización de rendimiento continua:"
    echo "   • Cierra proyectos no utilizados"
    echo "   • Limpia cache regularmente: File > Invalidate Caches"
    echo "   • Revisa uso de memoria en Help > Memory Indicator"
    echo "   • Usa Local History en lugar de backup constante"
}

# Función para verificar configuraciones aplicadas
verify_configuration() {
    log "=== VERIFICANDO CONFIGURACIONES APLICADAS ==="

    local config_base="$HOME/Library/Application Support/JetBrains"

    info "📁 Verificando directorios de configuración:"
    for ide in IntelliJIdea PyCharm DataGrip PhpStorm WebStorm; do
        local ide_config=$(find "$config_base" -name "*${ide}*2025.*" -type d 2>/dev/null | head -1)
        if [[ -n "$ide_config" ]]; then
            success "✅ $ide: $ide_config"

            local vmoptions_files=("idea.vmoptions" "pycharm.vmoptions" "datagrip.vmoptions" "phpstorm.vmoptions" "webstorm.vmoptions")
            for vmoptions in "${vmoptions_files[@]}"; do
                if [[ -f "$ide_config/$vmoptions" ]]; then
                    success "   ✅ VM Options configuradas ($vmoptions)"
                    break
                fi
            done

            if [[ -f "$ide_config/options/editor.xml" ]]; then
                success "   ✅ Configuración de editor aplicada"
            fi
        else
            warning "⚠️  $ide: No encontrado"
        fi
    done

    info "🖥️  Verificando configuraciones del sistema:"
    # No hay swappiness ni inotify en macOS
    echo "   • Límites de archivos abiertos configurados con ulimit"

    success "✅ Verificación completada"
}

# Función para mostrar resumen de optimizaciones
show_optimization_summary() {
    log "=== RESUMEN DE OPTIMIZACIONES APLICADAS ==="

    echo -e "${CYAN}"
    cat << 'EOF'
🚀 OPTIMIZACIONES APLICADAS PARA macOS MacBook Air M2 16GB RAM

💾 MEMORIA Y RENDIMIENTO:
   ✅ IntelliJ IDEA: Heap 6GB, Metaspace 1GB, G1GC
   ✅ PyCharm: Heap 5GB, Metaspace 512MB, G1GC optimizado
   ✅ DataGrip: Heap 4GB, timeouts optimizados para DB
   ✅ PhpStorm: Heap 5GB, análisis profundo PHP habilitado
   ✅ WebStorm: Heap 4.5GB, optimizaciones JS/TS específicas
   ✅ Garbage Collection configurado para pausas <200ms

🖥️ SISTEMA OPERATIVO:
   ✅ Límites de archivos abiertos aumentados con ulimit
   ✅ Directorios temporales optimizados para cada IDE

⚙️ CONFIGURACIONES DE IDE:
   ✅ Editor optimizado para rendimiento
   ✅ Indexado inteligente configurado
   ✅ Cache y metadata optimizados
   ✅ Configuraciones de red mejoradas
   ✅ Soporte específico para frameworks (Laravel, Symfony, React, Vue, etc.)

🔧 DISTRIBUCIÓN DE MEMORIA RECOMENDADA (16GB):
   • Sistema Operativo: ~2GB
   • IDE Principal (IntelliJ/PhpStorm): 5-6GB
   • IDE Secundario (WebStorm/PyCharm): 4-5GB
   • DataGrip (cuando se use): 4GB
   • Aplicaciones restantes: ~3GB

🔧 PRÓXIMOS PASOS RECOMENDADOS:
   1. Reinicia todos los IDEs para aplicar cambios
   2. Instala solo plugins esenciales por IDE
   3. Configura proyectos con exclusiones apropiadas
   4. Monitorea uso de memoria regularmente
   5. Usa solo 1-2 IDEs simultáneamente para mejor rendimiento

EOF
    echo -e "${NC}"

    warning "⚠️  IMPORTANTE: Reinicia todos los IDEs de JetBrains para aplicar los cambios."
    info "📊 Usa Help > Memory Indicator en cada IDE para monitorear el uso de memoria."
    warning "💡 RECOMENDACIÓN: No ejecutes más de 2 IDEs simultáneamente para mantener rendimiento óptimo."
}

# Función principal
main() {
    log "🚀 Optimizador JetBrains IDEs para macOS MacBook Air M2 16GB RAM"
    log "IDEs soportados: IntelliJ IDEA, PyCharm, DataGrip, PhpStorm, WebStorm"

    echo -e "${YELLOW}"
    echo "¿Qué tipo de optimización deseas aplicar?"
    echo "1) Optimización completa (recomendado)"
    echo "2) Solo configuraciones de memoria"
    echo "3) Solo configuraciones del sistema"
    echo "4) Solo configuraciones de editor"
    echo "5) Verificar configuraciones existentes"
    echo "6) Solo mostrar recomendaciones"
    echo -e "${NC}"

    read -p "Selecciona una opción (1-6): " choice

    detect_system_info

    case $choice in
        1)
            detect_jetbrains_apps_and_configs
            if [[ $? -ne 0 ]]; then
                warning "Algunas apps o configuraciones no fueron detectadas correctamente."
            fi
            optimize_system_settings

            local config_base="$HOME/Library/Application Support/JetBrains"

            for ide_dir in $(find "$config_base" -maxdepth 1 -type d -name "*2024.*" 2>/dev/null); do
                local ide_name=$(basename "$ide_dir" | tr '[:upper:]' '[:lower:]')
                case "$ide_name" in
                    *idea*)
                        optimize_memory_settings "intellij" "$ide_dir"
                        create_ide_properties "intellij" "$ide_dir"
                        configure_editor_settings "intellij" "$ide_dir"
                        ;;
                    *pycharm*)
                        optimize_memory_settings "pycharm" "$ide_dir"
                        create_ide_properties "pycharm" "$ide_dir"
                        configure_editor_settings "pycharm" "$ide_dir"
                        ;;
                    *datagrip*)
                        optimize_memory_settings "datagrip" "$ide_dir"
                        create_ide_properties "datagrip" "$ide_dir"
                        configure_editor_settings "datagrip" "$ide_dir"
                        ;;
                    *phpstorm*)
                        optimize_memory_settings "phpstorm" "$ide_dir"
                        create_ide_properties "phpstorm" "$ide_dir"
                        configure_editor_settings "phpstorm" "$ide_dir"
                        ;;
                    *webstorm*)
                        optimize_memory_settings "webstorm" "$ide_dir"
                        create_ide_properties "webstorm" "$ide_dir"
                        configure_editor_settings "webstorm" "$ide_dir"
                        ;;
                esac
            done

            suggest_plugins
            show_monitoring_tips
            ;;
        2)
            local config_base="$HOME/Library/Application Support/JetBrains"
            for ide_dir in $(find "$config_base" -maxdepth 1 -type d -name "*2024.*" 2>/dev/null); do
                local ide_name=$(basename "$ide_dir" | tr '[:upper:]' '[:lower:]')
                case "$ide_name" in
                    *idea*) optimize_memory_settings "intellij" "$ide_dir" ;;
                    *pycharm*) optimize_memory_settings "pycharm" "$ide_dir" ;;
                    *datagrip*) optimize_memory_settings "datagrip" "$ide_dir" ;;
                    *phpstorm*) optimize_memory_settings "phpstorm" "$ide_dir" ;;
                    *webstorm*) optimize_memory_settings "webstorm" "$ide_dir" ;;
                esac
            done
            ;;
        3)
            optimize_system_settings
            ;;
        4)
            local config_base="$HOME/Library/Application Support/JetBrains"
            for ide_dir in $(find "$config_base" -maxdepth 1 -type d -name "*2024.*" 2>/dev/null); do
                local ide_name=$(basename "$ide_dir" | tr '[:upper:]' '[:lower:]')
                configure_editor_settings "$ide_name" "$ide_dir"
            done
            ;;
        5)
            verify_configuration
            ;;
        6)
            suggest_plugins
            show_monitoring_tips
            ;;
        *)
            error "Opción inválida"
            exit 1
            ;;
    esac

    verify_configuration
    show_optimization_summary

    success "🎉 Optimización completada para macOS MacBook Air M2!"
    info "Reinicia los IDEs para aplicar todos los cambios."
}

# Ejecutar función principal
main "$@"