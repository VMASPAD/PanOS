#!/bin/bash

# PanOS - Run in QEMU

BUILD_DIR="$HOME/pan-os-iso/build"

echo "═══════════════════════════════════════"
echo "  PanOS - Run in QEMU"
echo "═══════════════════════════════════════"
echo ""

# Verify files
if [[ ! -f "$BUILD_DIR/vmlinuz" ]] || [[ ! -f "$BUILD_DIR/initramfs.cpio" ]]; then
    echo "❌ Error: Files not found"
    echo "   Run first: ./1-build.sh"
    exit 1
fi

# Memory menu
echo "Memory configuration:"
echo "1) 1 GB   (minimum)"
echo "2) 2 GB   (recommended for npm/vite) ← DEFAULT"
echo "3) 4 GB   (optimal for compilation)"
echo ""
read -p "Choose amount of RAM (1-3) [2]: " mem_option
mem_option=${mem_option:-2}

case "$mem_option" in
    1) MEM="1024" ;;
    3) MEM="4096" ;;
    *) MEM="2048" ;;
esac

echo ""
echo "Starting PanOS in QEMU with ${MEM}MB RAM..."
echo ""
echo "Press Ctrl+A then X to exit"
echo "═══════════════════════════════════════"
echo ""

sleep 1

qemu-system-x86_64 \
    -kernel "$BUILD_DIR/vmlinuz" \
    -initrd "$BUILD_DIR/initramfs.cpio" \
    -nographic -serial stdio -monitor none \
    -append "console=ttyS0" \
    -netdev user,id=net0,dns=10.0.2.3,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80,hostfwd=tcp::5173-:5173 \
    -device virtio-net-pci,netdev=net0 \
    -m "$MEM" -smp 2
