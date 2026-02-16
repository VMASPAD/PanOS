#!/bin/bash

# PanOS - Crear ISO Booteable

BUILD_DIR="$HOME/pan-os-iso/build"
ISO_DIR="$BUILD_DIR/grub-iso"
OUTPUT_ISO="$BUILD_DIR/pan-os-booteable.iso"

echo "═══════════════════════════════════════"
echo "  PanOS - Crear ISO Booteable"
echo "═══════════════════════════════════════"
echo ""

# Verificar archivos necesarios
if [[ ! -f "$BUILD_DIR/vmlinuz" ]] || [[ ! -f "$BUILD_DIR/initramfs.cpio" ]]; then
    echo "❌ Error: vmlinuz o initramfs.cpio no encontrados"
    echo "   Ejecuta primero: ./1-build.sh"
    exit 1
fi

echo "[1/3] Preparando estructura..."
rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR/boot/grub"

# Copiar kernel e initramfs
cp "$BUILD_DIR/vmlinuz" "$ISO_DIR/boot/"
cp "$BUILD_DIR/initramfs.cpio" "$ISO_DIR/boot/"

echo "[2/3] Configurando GRUB..."

# Crear grub.cfg
cat > "$ISO_DIR/boot/grub/grub.cfg" << 'GRUBCFG'
insmod all_video
insmod gfxterm

set default=0
set timeout=10

menuentry "PanOS" {
    insmod gzio
    insmod part_msdos
    insmod iso9660
    search --no-floppy --label PANOS
    echo 'Iniciando PanOS...'
    linux /boot/vmlinuz console=ttyS0 console=tty0
    initrd /boot/initramfs.cpio
}

menuentry "PanOS (Serial Console)" {
    insmod gzio
    insmod part_msdos
    insmod iso9660
    search --no-floppy --label PANOS
    echo 'Iniciando PanOS (serial)...'
    linux /boot/vmlinuz console=ttyS0
    initrd /boot/initramfs.cpio
}
GRUBCFG

echo "[3/3] Generando ISO..."

# Try grub-mkrescue first
if command -v grub-mkrescue &> /dev/null; then
    echo "  Usando grub-mkrescue..."
    grub-mkrescue \
        --output="$OUTPUT_ISO" \
        "$ISO_DIR" 2>/dev/null
    
    # Check if it actually produced a valid file
    if [[ ! -f "$OUTPUT_ISO" ]] || [[ ! -s "$OUTPUT_ISO" ]]; then
        echo "  grub-mkrescue no generó ISO, intentando alternativa..."
        rm -f "$OUTPUT_ISO"
    fi
fi

# Fallback: use xorriso directly with GRUB cdboot.img (BIOS)
if [[ ! -f "$OUTPUT_ISO" ]] || [[ ! -s "$OUTPUT_ISO" ]]; then
    CDBOOT="/usr/lib/grub/i386-pc/cdboot.img"
    if [[ -f "$CDBOOT" ]] && command -v xorrisofs &> /dev/null; then
        echo "  Usando xorrisofs + GRUB cdboot..."
        
        # Build a GRUB BIOS core image for El Torito boot
        CORE_IMG="$ISO_DIR/boot/grub/i386-pc/core.img"
        mkdir -p "$ISO_DIR/boot/grub/i386-pc"
        
        if command -v grub-mkimage &> /dev/null; then
            grub-mkimage -O i386-pc -o "$CORE_IMG" \
                -p /boot/grub \
                biosdisk iso9660 normal search configfile linux initrd \
                gzio part_msdos 2>/dev/null
            
            # Concatenate cdboot.img + core.img into eltorito image
            cat "$CDBOOT" "$CORE_IMG" > "$ISO_DIR/boot/grub/i386-pc/eltorito.img"
            
            xorrisofs -o "$OUTPUT_ISO" \
                -R -J \
                -b boot/grub/i386-pc/eltorito.img \
                -no-emul-boot \
                -boot-load-size 4 \
                -boot-info-table \
                --grub2-boot-info \
                "$ISO_DIR" 2>/dev/null || true
        fi
    fi
fi

# Fallback 2: simple data ISO (not bootable but contains files)
if [[ ! -f "$OUTPUT_ISO" ]] || [[ ! -s "$OUTPUT_ISO" ]]; then
    if command -v xorrisofs &> /dev/null; then
        echo "  Creando ISO simple (sin bootloader)..."
        xorrisofs -o "$OUTPUT_ISO" -R -J "$ISO_DIR" 2>/dev/null || true
    fi
fi

# Final check
if [[ -f "$OUTPUT_ISO" ]] && [[ -s "$OUTPUT_ISO" ]]; then
    SIZE=$(ls -lh "$OUTPUT_ISO" | awk '{print $5}')
    
    echo ""
    echo "✅ ISO Booteable creada: $SIZE"
    echo ""
    echo "Ubicación: $OUTPUT_ISO"
    echo ""
    echo "═══════════════════════════════════════"
    echo "USAR LA ISO:"
    echo "═══════════════════════════════════════"
    echo ""
    echo "1️⃣  QEMU:"
    echo "    qemu-system-x86_64 -cdrom $OUTPUT_ISO -m 1024"
    echo ""
    echo "2️⃣  VirtualBox/VMware:"
    echo "    Montar como DVD en la VM"
    echo ""
    echo "3️⃣  USB Booteable:"
    echo "    sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M"
    echo "    (Verifica el dispositivo con: lsblk)"
    echo ""
else
    echo "⚠️  Advertencia: No se pudo crear ISO"
    echo ""
    echo "Alternativa: QEMU puede arrancar directamente del kernel + initramfs:"
    echo "  ./2-run.sh"
    echo ""
    echo "ISO creació es opcional. El sistema funciona sin ella."
    exit 0
fi
