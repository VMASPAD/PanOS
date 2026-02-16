#!/bin/bash

#################################################################
# Test script to verify PanOS and QEMU Setup
# Optimized for interactive terminal
#################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   PanOS - QEMU & Terminal Interactiva Test     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Test 1: QEMU installed
echo "📋 Test 1: Check QEMU..."
if command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "${GREEN}✅ QEMU installed${NC}"
    qemu-system-x86_64 --version | head -1
else
    echo -e "${RED}❌ QEMU not installed${NC}"
    echo "   Install with: sudo apt install qemu-system-x86_64"
    exit 1
fi

echo ""

# Test 2: Verify image files
echo "📋 Test 2: Check image files..."
KERNEL="$HOME/pan-os/build/vmlinuz"
INITRD="$HOME/pan-os/build/initramfs.cpio"

if [ -f "$KERNEL" ]; then
    KSIZE=$(du -h "$KERNEL" | cut -f1)
    echo -e "${GREEN}✅ Kernel found${NC} (size: $KSIZE)"
else
    echo -e "${RED}❌ Kernel not found at $KERNEL${NC}"
    echo "   Run first: ./quickstart.sh"
    fi

if [ -f "$INITRD" ]; then
    ISIZE=$(du -h "$INITRD" | cut -f1)
    echo -e "${GREEN}✅ Initramfs found${NC} (size: $ISIZE)"
else
    echo -e "${RED}❌ Initramfs not found at $INITRD${NC}"
    echo "   Run first: ./quickstart.sh"
fi

echo ""

# Test 3: Check boot.js contains interactive shell
echo "📋 Test 3: Verify boot.js (should have spawn bash)..."
if [ -d "$HOME/pan-os/rootfs" ]; then
    if grep -q "spawn" "$HOME/pan-os/rootfs/boot.js" 2>/dev/null; then
        echo -e "${GREEN}✅ boot.js contiene terminal interactiva${NC}"
    else
        echo -e "${YELLOW}⚠️  boot.js podria no tener shell interactiva${NC}"
        echo "   (Esto puede estar bien, dep ending on your setup)"
    fi
else
    echo -e "${YELLOW}⚠️  Script no compilado aun, saltando test de boot.js${NC}"
fi

echo ""

# Test 4: Mostrar comando QEMU recommended
echo "📋 Test 4: Comando QEMU (terminal interactiva):"
echo ""
echo -e "${BLUE}qemu-system-x86_64 \\${NC}"
echo -e "${BLUE}  -kernel $KERNEL \\${NC}"
echo -e "${BLUE}  -initrd $INITRD \\${NC}"
echo -e "${BLUE}  -nographic \\${NC}"
echo -e "${BLUE}  -serial stdio \\${NC}"
echo -e "${BLUE}  -append \"console=ttyS0 loglevel=3\" \\${NC}"
echo -e "${BLUE}  -m 512 \\${NC}"
echo -e "${BLUE}  -smp 2 \\${NC}"
echo -e "${BLUE}  -monitor none${NC}"
echo ""

# Test 5: Informacion util
echo "📋 Test 5: Informacion sobre el uso:"
echo ""
echo "Despues de iniciar QEMU veras:"
echo "  1. Informacion del sistema (kernel, NodeJS, memoria)"
echo "  2. Lista de comandos disponibles"
echo "  3. Un prompt: ${YELLOW}PanOS\$${NC}"
echo ""
echo "Entonces tienes una ${YELLOW}shell Unix completa${NC}. Prueba:"
echo "  ${YELLOW}PanOS\$${NC} ls -la"
echo "  ${YELLOW}PanOS\$${NC} ps aux"
echo "  ${YELLOW}PanOS\$${NC} free -h"
echo "  ${YELLOW}PanOS\$${NC} uptime"
echo ""

# Test 6: Offer to run
echo "📋 Test 6: Do you want to test now?"
if [ -f "$KERNEL" ] && [ -f "$INITRD" ]; then
    read -p "Ejecutar QEMU (s/n): " choice
    if [[ $choice =~ ^[Ss]$ ]]; then
        echo ""
        echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}Iniciando PanOS en QEMU...${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}Tip: Escribe 'exit' para salir del OS${NC}"
        echo ""
        
        qemu-system-x86_64 \
          -kernel "$KERNEL" \
          -initrd "$INITRD" \
          -nographic \
          -serial stdio \
          -append "console=ttyS0 loglevel=3" \
          -m 512 \
          -smp 2 \
          -monitor none
        
        echo ""
        echo -e "${GREEN}✅ PanOS termino${NC}"
    fi
else
    echo -e "${RED}⚠️  Falta imagen. Ejecuta './quickstart.sh' first${NC}"
fi

echo ""
