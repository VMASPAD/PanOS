#!/bin/bash
# Script para ejecutar PanOS ISO o initramfs en QEMU con red

WORKSPACE="${HOME}/pan-os-iso"
BUILD="${WORKSPACE}/build"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PanOS QEMU Launcher con Red${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Check if images exist
if [ ! -f "${BUILD}/vmlinuz" ] || [ ! -f "${BUILD}/initramfs.cpio" ]; then
    echo -e "${RED}✗ Imagenes not foundadas en ${BUILD}/${NC}"
    echo "Run first: ./build-iso-with-NodeJS.sh"
    exit 1
fi

echo "Imagenes disponibles:"
ls -lh "${BUILD}/" | grep -E "vmlinuz|initramfs|iso"
echo ""

if [ -f "${BUILD}/PanOS-os.iso" ] && [ -s "${BUILD}/PanOS-os.iso" ]; then
    echo "Opciones de arranque:"
    echo "1) Runr desde ISO (booteo real)"
    echo "2) Runr desde initramfs (rapido)"
    echo ""
    read -p "Elige (1-2): " option
else
    option="2"
fi

echo ""
echo "Opciones de red:"
echo "1) User mode (NAT) - Facil, no requires permisos root"
echo "2) Bridge - Mas complete, requires configuracion previa"
echo ""
read -p "Elige tipo de red (1-2) [1]: " net_option
net_option=${net_option:-1}

# Configuracion de red
if [ "$net_option" = "2" ]; then
    # Bridge mode - requires tap configurado
    echo -e "${YELLOW}Modo Bridge requires configuracion previa${NC}"
    echo "Comandos necessarys (ejecutar como root):"
    echo "  ip tuntap add dev tap0 mode tap user \$(whoami)"
    echo "  ip link set tap0 up"
    echo "  ip link add br0 type bridge"
    echo "  ip link set wlp2s0 master br0  # reemplaza wlp2s0 por tu interfaz WiFi"
    echo "  ip link set tap0 master br0"
    echo "  ip link set br0 up"
    echo ""
    read -p "¿Ya configuraste el bridge? (s/n): " bridge_ready
    if [ "$bridge_ready" != "s" ]; then
        echo "Cancelando..."
        exit 1
    fi
    NET_OPTS="-netdev tap,id=net0,ifname=tap0,script=no,downscript=no,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80,hostfwd=tcp::5173-:5173 -device virtio-net-pci,netdev=net0"
else
    # User mode (mas simple, funciona sin root)
    NET_OPTS="-netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80,hostfwd=tcp::5173-:5173 -device virtio-net-pci,netdev=net0"
fi

echo ""
echo "Configuracion de memoria:"
echo "1) 1 GB   (minimo, para desarrollo ligero)"
echo "2) 2 GB   (recommended para npm/vite)"
echo "3) 4 GB   (optimo para Compilationon)"
echo ""
read -p "Elige cantidad de RAM (1-3) [2]: " mem_option
mem_option=${mem_option:-2}

case "$mem_option" in
    1) MEM_SIZE="1024" ;;
    2) MEM_SIZE="2048" ;;
    3) MEM_SIZE="4096" ;;
    *) MEM_SIZE="2048" ;;
esac

echo ""
echo -e "${BLUE}Iniciando QEMU con ${MEM_SIZE}MB de RAM...${NC}"
echo -e "${YELLOW}Para salir: Ctrl+A luego X${NC}"
if [ "$net_option" = "1" ]; then
    echo -e "${GREEN}Red: User mode NAT${NC}"
    echo -e "${GREEN}Port forwarding: localhost:8080->VM:80, localhost:2222->VM:22${NC}"
fi
echo ""

if [ "$option" = "1" ] && [ -f "${BUILD}/PanOS-os.iso" ] && [ -s "${BUILD}/PanOS-os.iso" ]; then
    # Boot from ISO
    qemu-system-x86_64 \
        -cdrom "${BUILD}/PanOS-os.iso" \
        -nographic \
        -serial stdio \
        -m "$MEM_SIZE" \
        -smp 2 \
        -monitor none \
        -append "console=ttyS0" \
        ${NET_OPTS}
else
    # Boot from kernel + initramfs
    qemu-system-x86_64 \
        -kernel "${BUILD}/vmlinuz" \
        -initrd "${BUILD}/initramfs.cpio" \
        -nographic \
        -serial stdio \
        -append "console=ttyS0" \
        -m "$MEM_SIZE" \
        -smp 2 \
        -monitor none \
        ${NET_OPTS}
fi

echo ""
echo -e "${GREEN}PanOS apagado${NC}"