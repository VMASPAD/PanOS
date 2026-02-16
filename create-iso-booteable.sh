#!/bin/bash

# Script para crear ISO booteable con SYSLINUX
# Más compatible que GRUB

set -e

BUILD_DIR="$HOME/pan-os-iso/build"
ISO_DIR="${BUILD_DIR}/iso-syslinux"
OUTPUT_ISO="${BUILD_DIR}/PanOS-os-booteable.iso"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Crear ISO Booteable con SYSLINUX - PanOS${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Verificar archivos necesarios
if [ ! -f "${BUILD_DIR}/vmlinuz" ] || [ ! -f "${BUILD_DIR}/initramfs.cpio" ]; then
    echo -e "${RED}✗ Error: vmlinuz o initramfs.cpio no encontrados${NC}"
    echo "  Ejecuta primero: ./build-iso-with-NodeJS.sh"
    exit 1
fi

echo "[1/4] Verificando herramientas..."

# Instalaciones necesarias
if ! command -v xorrisofs &> /dev/null; then
    echo "Instalando xorriso..."
    sudo apt-get install -y xorriso > /dev/null 2>&1 || {
        echo -e "${RED}✗ Error instalando xorriso${NC}"
        exit 1
    }
fi

# SYSLINUX es opcional, lo descargamos si es necesario
SYSLINUX_DIR="/tmp/syslinux-tmp"
if ! command -v isohybrid &> /dev/null; then
    echo "Descargando SYSLINUX..."
    mkdir -p "${SYSLINUX_DIR}"
    cd "${SYSLINUX_DIR}"
    
    # Usar versión pre-compilada o descargarla
    if [ ! -d "syslinux" ]; then
        # Intentar descargar pre-compilado
        wget -q "https://kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz" \
            -O syslinux.tar.xz 2>/dev/null || \
        wget -q "https://github.com/gfxboot/syslinux/releases/download/v6.03/syslinux-6.03.tar.xz" \
            -O syslinux.tar.xz 2>/dev/null || {
            echo -e "${YELLOW}⚠️  SYSLINUX no disponible, usando método alternativo${NC}"
            SYSLINUX_AVAILABLE=0
        }
        
        if [ -f "syslinux.tar.xz" ]; then
            tar -xf syslinux.tar.xz
            SYSLINUX_AVAILABLE=1
        fi
    fi
fi

echo "[2/4] Preparando estructura ISO..."
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/boot"
mkdir -p "${ISO_DIR}/isolinux"

# Copiar kernel e initramfs
cp "${BUILD_DIR}/vmlinuz" "${ISO_DIR}/boot/vmlinuz"
cp "${BUILD_DIR}/initramfs.cpio" "${ISO_DIR}/boot/initramfs.cpio"

echo "[3/4] Configurando bootloader..."

# Crear configuración de ISOLINUX
cat > "${ISO_DIR}/isolinux/isolinux.cfg" << 'ISOLINUX_EOF'
DEFAULT linux
TIMEOUT 50
PROMPT 1

LABEL linux
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs.cpio console=ttyS0 console=tty0 root=/dev/ram0 rw
    
LABEL vga
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs.cpio console=tty0 root=/dev/ram0 rw
ISOLINUX_EOF

# Obtener ISOLINUX.BIN
if [ -f "${SYSLINUX_DIR}/syslinux-6.03/bios/core/isolinux.bin" ]; then
    cp "${SYSLINUX_DIR}/syslinux-6.03/bios/core/isolinux.bin" "${ISO_DIR}/isolinux/"
    ISOLINUX_BIN="${ISO_DIR}/isolinux/isolinux.bin"
elif [ -f "/usr/lib/ISOLINUX/isolinux.bin" ]; then
    cp "/usr/lib/ISOLINUX/isolinux.bin" "${ISO_DIR}/isolinux/"
    ISOLINUX_BIN="${ISO_DIR}/isolinux/isolinux.bin"
elif [ -f "/usr/lib/x86_64-linux-gnu/syslinux/isolinux.bin" ]; then
    cp "/usr/lib/x86_64-linux-gnu/syslinux/isolinux.bin" "${ISO_DIR}/isolinux/"
    ISOLINUX_BIN="${ISO_DIR}/isolinux/isolinux.bin"
else
    echo -e "${RED}⚠️  isolinux.bin no encontrado${NC}"
    echo "Creando ISO sin bootloader específico (usar método UEFI)..."
    ISOLINUX_BIN=""
fi

echo "[4/4] Generando ISO..."

if [ -n "${ISOLINUX_BIN}" ] && [ -f "${ISOLINUX_BIN}" ]; then
    # Crear ISO con ISOLINUX (BIOS booteable)
    echo "  Método: ISOLINUX + xorrisofs (BIOS)"
    xorrisofs -o "${OUTPUT_ISO}" \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -R -J \
        -V "PanOS_OS" \
        "${ISO_DIR}" 2>/dev/null
else
    # Crear ISO simple (será booteable en UEFI o con QEMU si especifica kernel)
    echo "  Método: xorrisofs simple (UEFI/QEMU)"
    xorrisofs -o "${OUTPUT_ISO}" \
        -R -J \
        -V "PanOS_OS" \
        "${ISO_DIR}" 2>/dev/null
fi

# Intentar agregar MBR para booteo BIOS con isohybrid
if command -v isohybrid &> /dev/null; then
    echo "  Agregando MBR con isohybrid..."
    isohybrid "${OUTPUT_ISO}" 2>/dev/null || true
fi

if [ -f "${OUTPUT_ISO}" ] && [ -s "${OUTPUT_ISO}" ]; then
    echo -e "${GREEN}✓ ISO creada exitosamente${NC}"
    ls -lh "${OUTPUT_ISO}"
    echo ""
    echo "Para usar en QEMU:"
    echo "  qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -m 1024 -boot d"
    echo ""
    echo "Para usar en una máquina virtual:"
    echo "  Montarla como unidad DVD en VirtualBox, VMware, Hyper-V, etc."
else
    echo -e "${RED}✗ Error creando ISO${NC}"
    exit 1
fi
