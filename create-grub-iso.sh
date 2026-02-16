#!/bin/bash

# Script SIMPLE para crear ISO booteable con GRUB
# (grub-mkrescue ya está instalado)

BUILD_DIR="$HOME/pan-os-iso/build"
ISO_DIR="${BUILD_DIR}/grub-iso"
OUTPUT_ISO="${BUILD_DIR}/PanOS-os-booteable.iso"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Crear ISO Booteable con GRUB${NC}"
echo ""

# Verificar archivos
if [ ! -f "${BUILD_DIR}/vmlinuz" ] || [ ! -f "${BUILD_DIR}/initramfs.cpio" ]; then
    echo -e "${RED}✗ vmlinuz o initramfs.cpio no encontrados${NC}"
    exit 1
fi

echo "[1/2] Preparando estructura..."
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/boot/grub"

# Copiar kernel
cp "${BUILD_DIR}/vmlinuz" "${ISO_DIR}/boot/"
cp "${BUILD_DIR}/initramfs.cpio" "${ISO_DIR}/boot/"

# Crear grub.cfg (IMPORTANTE: configuración correcta)
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'GRUBCFG'
insmod all_video
insmod gfxterm

set default=0
set timeout=10

menuentry "PanOS" {
    insmod gzio
    insmod part_msdos
    insmod iso9660
    search --no-floppy --label PanOS_OS
    echo 'Cargando PanOS...'
    multiboot /boot/vmlinuz console=ttyS0 console=tty0
    module /boot/initramfs.cpio
}

menuentry "PanOS (serial)" {
    insmod gzio
    insmod part_msdos
    insmod iso9660
    search --no-floppy --label PanOS_OS
    echo 'Arrancando en modo serial...'
    linux /boot/vmlinuz console=ttyS0 root=/dev/ram0
    initrd /boot/initramfs.cpio
}
GRUBCFG

echo "[2/2] Generando ISO con grub-mkrescue..."
grub-mkrescue \
    --output="${OUTPUT_ISO}" \
    --label=PanOS_OS \
    "${ISO_DIR}" 2>/dev/null

if [ -f "${OUTPUT_ISO}" ] && [ -s "${OUTPUT_ISO}" ]; then
    SIZE=$(ls -lh "${OUTPUT_ISO}" | awk '{print $5}')
    
    echo -e "${GREEN}✓ ISO Booteable creada exitosamente${NC}"
    echo ""
    echo "Archivo: ${OUTPUT_ISO}"
    echo "Tamaño: ${SIZE}"
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "PARA USAR EN QEMU:"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "qemu-system-x86_64 -cdrom ${OUTPUT_ISO} \\"
    echo "  -m 1024 -smp 2 \\"
    echo "  -nographic -serial stdio -monitor none"
    echo ""
    echo "O con video:"
    echo "qemu-system-x86_64 -cdrom ${OUTPUT_ISO} \\"
    echo "  -m 1024 -smp 2 -vga std"
    echo ""
else
    echo -e "${RED}✗ Error creando ISO${NC}"
    exit 1
fi
