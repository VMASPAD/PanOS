#!/bin/bash

# PanOS - Script de instalación de dependencias

echo "═══════════════════════════════════════"
echo "  PanOS - Instalar Dependencias"
echo "═══════════════════════════════════════"
echo ""

# Lista de paquetes necesarios
PACKAGES=(
    "build-essential"
    "bc"
    "bison"
    "flex"
    "git"
    "ca-certificates"
    "libelf-dev"
    "libssl-dev"
    "wget"
    "xz-utils"
    "cpio"
    "grub-common"
    "xorriso"
    "qemu-system-x86"
)

echo "Instalando paquetes necesarios..."
echo ""

sudo apt-get update -qq
sudo apt-get install -y "${PACKAGES[@]}"

echo ""
echo "✓ Dependencias instaladas correctamente"
echo ""
echo "Siguiente paso: ./1-build.sh"
