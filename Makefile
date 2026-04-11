# PanOS Makefile
# Usage: make [target]

.PHONY: help build auto run qemu iso deps check clean rebuild docker arm64

SCRIPT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

help:
	@echo ""
	@echo "  PanOS - Build Targets"
	@echo "  ─────────────────────────────────"
	@echo ""
	@echo "  make build    Build kernel + rootfs"
	@echo "  make auto     Full build (deps + build + ISO)"
	@echo "  make run      Run in QEMU"
	@echo "  make iso      Create bootable ISO"
	@echo "  make deps     Install dependencies"
	@echo "  make check    Check build status"
	@echo "  make docker   Build & run with Docker"
	@echo "  make arm64    Build for ARM64"
	@echo "  make clean    Remove build artifacts"
	@echo "  make rebuild  Clean + full build"
	@echo "  make menu     Interactive menu"
	@echo ""

build:
	@bash $(SCRIPT_DIR)scripts/build/build-system.sh

auto:
	@bash $(SCRIPT_DIR)panos.sh --auto

run qemu:
	@bash $(SCRIPT_DIR)scripts/run/run-qemu.sh

iso:
	@bash $(SCRIPT_DIR)scripts/iso/create-iso.sh

deps:
	@bash $(SCRIPT_DIR)scripts/build/install-deps.sh

check:
	@bash $(SCRIPT_DIR)scripts/utils/check-build.sh

docker:
	@cd $(SCRIPT_DIR) && docker compose up --build

arm64:
	@bash $(SCRIPT_DIR)scripts/build/build-arm64.sh

clean:
	@echo "Cleaning ~/pan-os-iso..."
	@rm -rf ~/pan-os-iso
	@echo "Done."

rebuild: clean auto

menu:
	@bash $(SCRIPT_DIR)panos.sh

.DEFAULT_GOAL := help
