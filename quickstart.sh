#!/bin/bash

#################################################################
# PanOS - Quick Start Script
# Una sola línea para crear tu OS
#################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                    PanOS QUICK START               ║"
echo "║         Greatest OS for Any Task - Pan OS Edition         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Detectar directorio del script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Verificar que build-PanOS-os.sh existe
if [ ! -f "${SCRIPT_DIR}/build-PanOS-os.sh" ]; then
    echo "❌ Error: build-PanOS-os.sh no encontrado en ${SCRIPT_DIR}"
    exit 1
fi

echo "📋 Verificar requisitos previos..."
echo "   ejecutando verificación de dependencias..."
echo ""

# Ejecutar script de build en modo automático
"${SCRIPT_DIR}/build-PanOS-os.sh" --auto

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              ✅ BUILD COMPLETADO EXITOSAMENTE             ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "📍 Tu PanOS está listo en: ~/pan-os/build/"
    echo ""
    echo "🚀 Para ejecutar de nuevo:"
    echo "   qemu-system-x86_64 \\"
    echo "     -kernel ~/pan-os/build/vmlinuz \\"
    echo "     -initrd ~/pan-os/build/initramfs.cpio \\"
    echo "     -nographic -append 'console=ttyS0' -m 512"
    echo ""
else
    echo ""
    echo "❌ Error durante la construcción"
    exit 1
fi
