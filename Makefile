# Makefile for PanOS Build
# Usage: make [target]

.PHONY: help auto quick menu run qemu clean rebuild

# Detect script dir
SCRIPT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

help:
	@echo "╔════════════════════════════════════════╗"
	@echo "║ PanOS - Makefile Targets        		║"
	@echo "╚════════════════════════════════════════╝"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  make auto     - Complete automatic build"
	@echo "  make quick    - Fast (alias of auto)"
	@echo "  make menu     - Interactive menu"
	@echo "  make qemu     - Run in QEMU"
	@echo "  make run      - Alias of qemu"
	@echo "  make clean    - Clean ~/pan-os"
	@echo "  make rebuild  - Clean and rebuild everything"
	@echo "  make deps     - Check dependencies"
	@echo ""

auto:
	@echo "🔨 Building PanOS automatically..."
	@bash $(SCRIPT_DIR)build-PanOS-os.sh --auto

quick: auto
	@echo "✅ Build completed"

menu:
	@echo "📋 Opening interactive menu..."
	@bash $(SCRIPT_DIR)build-PanOS-os.sh

deps:
	@echo "✅ Checking dependencies..."
	@bash $(SCRIPT_DIR)build-PanOS-os.sh
	@read -p "Press Enter..."

qemu:
	@if [ -f ~/pan-os/build/vmlinuz ] && [ -f ~/pan-os/build/initramfs.cpio ]; then \
		echo "🚀 Running PanOS in QEMU..."; \
		qemu-system-x86_64 \
			-kernel ~/pan-os/build/vmlinuz \
			-initrd ~/pan-os/build/initramfs.cpio \
			-nographic \
			-append "console=ttyS0" \
			-m 512 \
			-smp 2; \
	else \
		echo "❌ Image not found. Run 'make auto' first."; \
	fi

run: qemu

clean:
	@echo "🗑️  Cleaning ~/pan-os..."
	@rm -rf ~/pan-os
	@echo "✅ Cleanup completed"

rebuild: clean auto
	@echo "✅ Rebuild completed"

.DEFAULT_GOAL := help
