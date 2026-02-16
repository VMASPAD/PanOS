#!/bin/bash

# PanOS - Ejecutar en QEMU

BUILD_DIR="$HOME/pan-os-iso/build"

echo "═══════════════════════════════════════"
echo "  PanOS - Ejecutar en QEMU"
echo "═══════════════════════════════════════"
echo ""

# Verificar archivos
if [[ ! -f "$BUILD_DIR/vmlinuz" ]] || [[ ! -f "$BUILD_DIR/initramfs.cpio" ]]; then
    echo "❌ Error: Archivos no encontrados"
    echo "   Ejecuta primero: ./1-build.sh"
    exit 1
fi

# Menú de memoria
echo "Configuración de memoria:"
echo "1) 1 GB   (mínimo)"
echo "2) 2 GB   (recomendado para npm/vite) ← DEFAULT"
echo "3) 4 GB   (óptimo para compilación)"
echo ""
read -p "Elige cantidad de RAM (1-3) [2]: " mem_option
mem_option=${mem_option:-2}

case "$mem_option" in
    1) MEM="1024" ;;
    3) MEM="4096" ;;
    *) MEM="2048" ;;
esac

echo ""
echo "Iniciando PanOS en QEMU con ${MEM}MB de RAM..."
echo ""
echo "Presiona Ctrl+A luego X para salir"
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
