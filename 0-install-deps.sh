#!/bin/bash

# PanOS - Dependency Installation Script

echo "═══════════════════════════════════════"
echo "  PanOS - Install Dependencies"
echo "═══════════════════════════════════════"
echo ""

# List of required packages
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

echo "Installing required packages..."
echo ""

sudo apt-get update -qq
sudo apt-get install -y "${PACKAGES[@]}"

echo ""
echo "✓ Dependencies installed successfully"
echo ""
echo "Next step: ./1-build.sh"
