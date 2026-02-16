#!/bin/bash

# Script for diagnostico para PanOS

set -e

WORKSPACE="${HOME}/pan-os"
ROOTFS="${WORKSPACE}/rootfs"
BUILD="${WORKSPACE}/build"
KERNEL_VERSION="6.6.15"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PanOS - DIAGNOSTIC TEST${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Clean previous build
echo -e "${YELLOW}[1/4] Cleaning build anterior...${NC}"
rm -rf "${WORKSPACE}" 2>/dev/null || true
mkdir -p "${WORKSPACE}/kernel-src" "${ROOTFS}" "${BUILD}"
echo -e "${GREEN}✓ Limpieza completada${NC}"
echo ""

# Step 2: Download and minimal kernel
echo -e "${YELLOW}[2/4] Downloading y compilando kernel minimal...${NC}"
cd "${WORKSPACE}/kernel-src"

# Download kernel
if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
    echo "  Downloading kernel (puede tomar 2-5 min)..."
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz" || {
        echo -e "${RED}Error descargando kernel${NC}"
        exit 1
    }
fi

if [ ! -d "linux-${KERNEL_VERSION}" ]; then
    tar -xf "linux-${KERNEL_VERSION}.tar.xz"
fi

cd "linux-${KERNEL_VERSION}"

# Build kernel with basic config
echo "  Configurando kernel..."
make allnoconfig > /dev/null 2>&1

# Add minimal serial config
cat > .config << 'EOF'
CONFIG_64BIT=y
CONFIG_X86=y
CONFIG_X86_64=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_CORE=y
CONFIG_SERIAL_CORE_CONSOLE=y
CONFIG_PRINTK=y
CONFIG_EARLY_PRINTK=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_EXT4_FS=y
CONFIG_BINFMT_ELF=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
EOF

make oldconfig < /dev/null > /dev/null 2>&1

echo "  Compiling kernel (puede tomar 10-30 min)..."
make -j$(nproc) 2>&1 | tail -20

if [ ! -f "arch/x86/boot/bzImage" ]; then
    echo -e "${RED}✗ Error compilando kernel${NC}"
    exit 1
fi

cp arch/x86/boot/bzImage "${BUILD}/vmlinuz"
echo -e "${GREEN}✓ Kernel compilado y copiado${NC}"
echo ""

# Step 3: Create simple rootfs
echo -e "${YELLOW}[3/4] Creating rootfs simple...${NC}"
cd "${ROOTFS}"

# Descargar busybox
echo "  Downloading busybox..."
mkdir -p bin
cd bin
wget -q "https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox" -O busybox || {
    echo -e "${RED}Error descargando busybox, intentando alternativa...${NC}"
    wget -q "https://github.com/mirror/busybox/releases/download/1.35.0/busybox-x86_64" -O busybox || {
        echo -e "${RED}No se pudo descargar busybox${NC}"
        exit 1
    }
}

chmod +x busybox
./busybox --install . > /dev/null 2>&1
echo -e "${GREEN}✓ Busybox instalado${NC}"
cd "${ROOTFS}"

# Create directory structure
mkdir -p dev etc lib proc sbin sys tmp root usr/bin usr/lib var/lib var/log boot

# Create init script
cat > init << 'INIT_EOF'
#!/bin/busybox sh
exec 2>&1
echo "Montando filesystems..."
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys
busybox mount -t devtmpfs devtmpfs /dev
busybox mount -t tmpfs tmpfs /tmp

echo "Creating dispositivos..."
[ -e /dev/console ] || busybox mknod /dev/console c 5 1
[ -e /dev/tty ] || busybox mknod /dev/tty c 5 0
[ -e /dev/null ] || busybox mknod /dev/null c 1 3

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   🚀 PanOS - Shell Ready       ║"
echo "╚════════════════════════════════════════╝"
echo ""
exec /bin/busybox sh
INIT_EOF

chmod +x init
echo -e "${GREEN}✓ Rootfs creado${NC}"
echo ""

# Step 4: Create initramfs
echo -e "${YELLOW}[4/4] Packageando initramfs...${NC}"
cd "${ROOTFS}"
find . -print0 | cpio -0 -o -H newc > "${BUILD}/initramfs.cpio" 2>/dev/null

if [ ! -f "${BUILD}/initramfs.cpio" ]; then
    echo -e "${RED}Error creando initramfs${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Initramfs creado${NC}"
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ BUILD COMPLETADO EXITOSAMENTE${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "Kernel: $(ls -h ${BUILD}/vmlinuz)"
echo "Initramfs: $(ls -h ${BUILD}/initramfs.cpio)"
echo ""
echo "Para ejecutar:"
echo ""
echo "  qemu-system-x86_64 \\"
echo "    -kernel ${BUILD}/vmlinuz \\"
echo "    -initrd ${BUILD}/initramfs.cpio \\"
echo "    -nographic -serial stdio \\"
echo "    -append \"console=ttyS0 loglevel=7\" \\"
echo "    -m 512 -smp 2 -monitor none"
echo ""
echo "O simplemente:"
echo ""
echo "  ./test-qemu-simple.sh"
echo ""
