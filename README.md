# Dev Environment

Repositorio único para levantar, destruir y recrear entornos de desarrollo completos en **Linux (Arch, Ubuntu, Fedora)**, **Windows 11** y **macOS** sin fricción ni pasos manuales innecesarios.

Si una máquina falla, se cambia o se formatea, este repo permite volver a ser productivo en minutos.

> Enfoque probado: dotfiles + bootstrap reproducible + automatización por OS

---

## Principio operativo

- Un solo repositorio
- Un comando por sistema operativo
- Cero secretos versionados
- Todo debe ser reproducible
- Todo debe poder borrarse y reinstalarse

Si algo no cumple esto, no pertenece aquí.

---

## Objetivo real del repo

Un solo comando por sistema operativo que:

- Instale el package manager base.
- Instale herramientas de sistema y de dev.
- Configure shell, editor e IDE.
- Sincronice dotfiles.
- Deje el entorno listo para trabajar.
- Evitar pasos manuales salvo login y permisos.

---

## Filosofía

Este repositorio existe para una sola cosa: **arrancar un entorno de desarrollo funcional, consistente y productivo en el menor tiempo posible**, sin importar el sistema operativo ni el hardware.

Ver más en [philosophy.md](philosophy.md)

---

## Estructura general propuesta

```plaintext
.
├── bootstrap/        # Arranque inicial por sistema operativo
├── docs/             # Documentación y decisiones técnicas
├── dotfiles/         # Configuración de shell, git, editores
├── installers/       # Instaladores específicos (docker, node, etc.)
├── packages/         # Listas de software por OS
├── scripts/          # Scripts reutilizables e idempotentes
├── Makefile          # Punto único de entrada
├── philosophy.md     # Filosofía y objetivos del repo
└── README.md
```

---

## Flujo recomendado (todos los sistemas)

1. Sistema operativo limpio
2. Ejecutar script de `bootstrap`
3. Ejecutar `make <os>`
4. Trabajar

No hay pasos manuales intermedios.

---

## Linux

Este repositorio soporta **Arch**, **Ubuntu** y **Fedora**. Cada distro tiene particularidades, pero el contrato es el mismo.

### Organización

```plaintext
bootstrap/linux.sh
packages/
  ├── arch.txt
  ├── ubuntu.txt
  └── fedora.txt
scripts/linux/
```

### Bootstrap (Linux)

Responsabilidad:

- Detectar la distro
- Instalar el package manager base si es necesario
- Instalar dependencias mínimas (git, curl, make)

El bootstrap **no instala todo**. Solo deja el sistema listo para ejecutar `make`.

### Paquetes

Cada distro tiene su archivo de paquetes:

- `arch.txt` → pacman / yay
- `ubuntu.txt` → apt
- `fedora.txt` → dnf

Estos archivos son listas puras. Sin lógica. Sin condiciones.

### Scripts

- Scripts comunes viven en `scripts/common`
- Scripts específicos de Linux en `scripts/linux`

---

## Windows 11

Windows se trata como ciudadano de primera clase, no como excepción.

### Organización

```plaintext
bootstrap/windows.ps1
packages/windows.txt
scripts/windows/
```

### Bootstrap (Windows)

Responsabilidad:

- Validar versión de Windows
- Habilitar ejecución de scripts
- Instalar Winget (si no existe)
- Instalar herramientas base

Después de esto, el sistema debe poder ejecutar:

```plaintext
make windows
```

### Paquetes

`packages/windows.txt` contiene IDs de Winget.

Ejemplo:

```plaintext
Git.Git
OpenJS.NodeJS
Docker.DockerDesktop
Microsoft.VisualStudioCode
```

Nada de installers manuales.

---

## macOS

macOS sigue el mismo modelo, sin atajos.

### Organización

```plaintext
bootstrap/macos.sh
packages/macos.txt
scripts/macos/
```

### Bootstrap (macOS)

Responsabilidad:

- Instalar Homebrew
- Instalar herramientas base
- Preparar el sistema para `make`

No se configuran dotfiles aquí.

### Paquetes

`packages/macos.txt` contiene fórmulas y casks.

Ejemplo:

```plaintext
git
node
docker
visual-studio-code
```

---

## Dotfiles

Las configuraciones viven en `dotfiles/` y se enlazan por symlinks.

Reglas:

- Nada específico de una máquina
- Nada hardcodeado
- Nada temporal

Ejemplos:

```plaintext
dotfiles/git/.gitconfig      → ~/.gitconfig
dotfiles/shell/.zshrc        → ~/.zshrc
dotfiles/vscode/settings.json
```

La creación de symlinks se hace siempre por script.

---

## VSCode e IDEs

### VSCode

Se versionan:

- `settings.json`
- `keybindings.json`
- Lista de extensiones

Las extensiones se reinstalan automáticamente por script.

### IntelliJ

Solo se versiona lo portable:

- Keymaps
- Plugins
- `ide.properties`

Nunca configuraciones completas por versión.

---

## Makefile

El `Makefile` es el punto único de entrada.

Ejemplos:

```plaintext
make arch
make ubuntu
make fedora
make windows
make macos
```

Si no se puede ejecutar desde `make`, no está terminado.

---

## Secretos

Este repositorio **no contiene secretos**.

- Usar `.env.example`
- Usar gestores de contraseñas
- Usar variables de entorno

Cualquier secreto versionado invalida el repositorio.

---

## Regla de oro

Este repo existe para reducir fricción, no para coleccionar configuraciones.

Si algo no ayuda a ser productivo desde el primer arranque, se elimina.
