#!/bin/bash

# Script para crear ISO booteable de PanOS

set -e

BUILD_DIR="$HOME/pan-os-iso/build"
ISO_DIR="${BUILD_DIR}/iso-temp"
OUTPUT_ISO="${BUILD_DIR}/PanOS-os.iso"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Crear ISO Booteable - PanOS${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Verificar archivos necesarios
if [ ! -f "${BUILD_DIR}/vmlinuz" ] || [ ! -f "${BUILD_DIR}/initramfs.cpio" ]; then
    echo -e "${RED}✗ Error: vmlinuz o initramfs.cpio no encontrados${NC}"
    echo "  Ejecuta primero: ./build-iso-with-NodeJS.sh"
    exit 1
fi

echo "[1/3] Preparando estructura ISO..."
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/boot/grub"

# Copiar kernel e initramfs
cp "${BUILD_DIR}/vmlinuz" "${ISO_DIR}/boot/vmlinuz"
cp "${BUILD_DIR}/initramfs.cpio" "${ISO_DIR}/boot/initramfs.cpio"

echo "[2/3] Creando configuración GRUB..."

# Crear grub.cfg
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'GRUB_EOF'
menuentry 'PanOS' {
    insmod gzio
    insmod part_msdos
    insmod ext2
    search --no-floppy --label PanOS_OS
    echo    'Iniciando PanOS...'
    linux   /boot/vmlinuz console=ttyS0 console=tty0
    initrd  /boot/initramfs.cpio
}
GRUB_EOF

echo "[3/3] Generando ISO..."

# Método 1: Intentar con grub-mkrescue (más simple)
if command -v grub-mkrescue &> /dev/null; then
    echo "  Usando: grub-mkrescue"
    grub-mkrescue -o "${OUTPUT_ISO}" "${ISO_DIR}" 2>/dev/null && {
        echo -e "${GREEN}✓ ISO creada exitosamente${NC}"
        ls -lh "${OUTPUT_ISO}"
        exit 0
    }
fi

# Método 2: Intentar con xorrisofs
if command -v xorrisofs &> /dev/null; then
    echo "  Usando: xorrisofs"
    xorrisofs -o "${OUTPUT_ISO}" \
        -b boot/grub/stage2_eltorito \
        -no-emul-boot -boot-load-size 4 \
        -boot-info-table \
        -R -J \
        -volid "PanOS_OS" \
        "${ISO_DIR}" 2>/dev/null && {
        echo -e "${GREEN}✓ ISO creada exitosamente${NC}"
        ls -lh "${OUTPUT_ISO}"
        exit 0
    }
fi

# Método 3: Intentar con mkisofs
if command -v mkisofs &> /dev/null; then
    echo "  Usando: mkisofs"
    mkisofs -o "${OUTPUT_ISO}" \
        -R -J \
        -volid "PanOS_OS" \
        "${ISO_DIR}" 2>/dev/null && {
        echo -e "${GREEN}✓ ISO creada exitosamente${NC}"
        ls -lh "${OUTPUT_ISO}"
        exit 0
    }
fi

# Si nada funciona
echo -e "${RED}✗ No se encontraron herramientas ISO${NC}"
echo ""
echo "Instala una de estas herramientas:"
echo "  sudo apt-get install grub2-common xorriso"
echo "  o"
echo "  sudo apt-get install mkisofs"
exit 1
