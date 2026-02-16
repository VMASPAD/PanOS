# Makefile para PanOS Build
# Uso: make [target]

.PHONY: help auto quick menu run qemu clean rebuild

# Detectar script dir
SCRIPT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

help:
	@echo "╔════════════════════════════════════════╗"
	@echo "║ PanOS - Makefile Targets        ║"
	@echo "╚════════════════════════════════════════╝"
	@echo ""
	@echo "Targets disponibles:"
	@echo ""
	@echo "  make auto     - Construcción automática completa"
	@echo "  make quick    - Rápido (alias de auto)"
	@echo "  make menu     - Menú interactivo"
	@echo "  make qemu     - Ejecutar en QEMU"
	@echo "  make run      - Alias de qemu"
	@echo "  make clean    - Limpiar ~/pan-os"
	@echo "  make rebuild  - Limpiar y reconstruir todo"
	@echo "  make deps     - Verificar dependencias"
	@echo ""

auto:
	@echo "🔨 Construyendo PanOS automáticamente..."
	@bash $(SCRIPT_DIR)build-PanOS-os.sh --auto

quick: auto
	@echo "✅ Build completado"

menu:
	@echo "📋 Abriendo menú interactivo..."
	@bash $(SCRIPT_DIR)build-PanOS-os.sh

deps:
	@echo "✅ Verificando dependencias..."
	@bash $(SCRIPT_DIR)build-PanOS-os.sh
	@read -p "Presiona Enter..."

qemu:
	@if [ -f ~/pan-os/build/vmlinuz ] && [ -f ~/pan-os/build/initramfs.cpio ]; then \
		echo "🚀 Ejecutando PanOS en QEMU..."; \
		qemu-system-x86_64 \
			-kernel ~/pan-os/build/vmlinuz \
			-initrd ~/pan-os/build/initramfs.cpio \
			-nographic \
			-append "console=ttyS0" \
			-m 512 \
			-smp 2; \
	else \
		echo "❌ Imagen no encontrada. Ejecuta 'make auto' primero."; \
	fi

run: qemu

clean:
	@echo "🗑️  Limpiando ~/pan-os..."
	@rm -rf ~/pan-os
	@echo "✅ Limpieza completada"

rebuild: clean auto
	@echo "✅ Reconstrucción completada"

.DEFAULT_GOAL := help
