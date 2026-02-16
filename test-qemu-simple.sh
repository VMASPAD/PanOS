#!/bin/bash

# Script simple para ejecutar QEMU con debug

WORKSPACE="${HOME}/pan-os"
BUILD="${WORKSPACE}/build"

if [ ! -f "${BUILD}/vmlinuz" ] || [ ! -f "${BUILD}/initramfs.cpio" ]; then
    echo "Error: Imágenes no encontradas en ${BUILD}/"
    echo "Ejecuta primero: ./build-simple.sh"
    exit 1
fi

echo "Iniciando PanOS en QEMU..."
echo "Para salir: Ctrl+A luego X"
echo ""

qemu-system-x86_64 \
  -kernel "${BUILD}/vmlinuz" \
  -initrd "${BUILD}/initramfs.cpio" \
  -nographic \
  -serial stdio \
  -append "console=ttyS0 loglevel=7" \
  -m 512 \
  -smp 2 \
  -monitor none

echo ""
echo "PanOS apagado"
