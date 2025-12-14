# Punto único de entrada para levantar el entorno de desarrollo
# Cada target delega la ejecución a su script correspondiente
# Por ahora, todos ejecutan un "hello world" controlado

.PHONY: arch ubuntu fedora windows macos help

help:
	@echo "Targets disponibles:"
	@echo "  make arch     → Linux Arch"
	@echo "  make ubuntu   → Linux Ubuntu"
	@echo "  make fedora   → Linux Fedora"
	@echo "  make windows  → Windows 11"
	@echo "  make macos    → macOS"

arch:
	@echo "[make] Ejecutando entorno Arch Linux"
	@./scripts/arch/hello.sh

ubuntu:
	@echo "[make] Ejecutando entorno Ubuntu"
	@./scripts/ubuntu/hello.sh

fedora:
	@echo "[make] Ejecutando entorno Fedora"
	@./scripts/fedora/hello.sh

macos:
	@echo "[make] Ejecutando entorno macOS"
	@./scripts/macos/hello.sh

windows:
	@echo "[make] Ejecutando entorno Windows 11"
	@powershell -ExecutionPolicy Bypass -File scripts/windows/hello.ps1
