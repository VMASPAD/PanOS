#!/bin/bash

# Script para crear ISO booteable - PanOS
# Usa las herramientas disponibles: mkisofs/xorrisofs + isohybrid

set -e

BUILD_DIR="$HOME/pan-os-iso/build"
ISO_DIR="${BUILD_DIR}/iso-boot"
OUTPUT_ISO="${BUILD_DIR}/PanOS-os-booteable.iso"

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
mkdir -p "${ISO_DIR}/boot"
mkdir -p "${ISO_DIR}/isolinux"

# Copiar kernel e initramfs
cp "${BUILD_DIR}/vmlinuz" "${ISO_DIR}/boot/vmlinuz"
cp "${BUILD_DIR}/initramfs.cpio" "${ISO_DIR}/boot/initramfs.cpio"

echo "[2/3] Configurando ISOLINUX..."

# Crear configuración de ISOLINUX
cat > "${ISO_DIR}/isolinux/isolinux.cfg" << 'ISOLINUX_EOF'
DEFAULT linux
TIMEOUT 50
PROMPT 1
LABEL linux
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs.cpio console=ttyS0 console=tty0 rw
ISOLINUX_EOF

# Crear directorio de boot.cat (requerido)
touch "${ISO_DIR}/isolinux/boot.cat"

echo "[3/3] Generando ISO booteable..."

# Crear ISO con xorrisofs (mejor soporte BIOS/UEFI)
xorrisofs \
    -o "${OUTPUT_ISO}" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -R -J \
    -V "PanOS_OS" \
    "${ISO_DIR}" 2>&1 | grep -v "^xorriso"

# Agregar soporte de arranque híbrido BIOS/UEFI con isohybrid
echo "  Mejorando compatibilidad de BIOS..."
isohybrid "${OUTPUT_ISO}" 2>/dev/null || true

# Verificar ISO
if [ -f "${OUTPUT_ISO}" ] && [ -s "${OUTPUT_ISO}" ]; then
    SIZE=$(ls -lh "${OUTPUT_ISO}" | awk '{print $5}')
    echo ""
    echo -e "${GREEN}✓ ISO Booteable creada${NC}"
    echo ""
    echo "Ubicación: ${OUTPUT_ISO}"
    echo "Tamaño: ${SIZE}"
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "COMANDOS PARA USAR LA ISO:"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "1️⃣  QEMU (serial + video):"
    echo "    qemu-system-x86_64 -cdrom ${OUTPUT_ISO} \\"
    echo "      -m 1024 -smp 2 \\"
    echo "      -serial stdio -nographic -monitor none"
    echo ""
    echo "2️⃣  VirtualBox:"
    echo "    VBoxManage createvm --name PanOS_OS --ostype Linux_64"
    echo "    VBoxManage setproperty machinefolder /tmp"
    echo "    Luego montarla como DVD"
    echo ""
    echo "3️⃣  Quemar en USB (DANGEROUS!):"
    echo "    sudo dd if=${OUTPUT_ISO} of=/dev/sdX bs=4M status=progress"
    echo "    Reemplaza /dev/sdX con tu USB (verificar con lsblk)"
    echo ""
else
    echo -e "${RED}✗ Error creando ISO${NC}"
    exit 1
fi
