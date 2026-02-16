#!/bin/bash

# PanOS - Verificar estado del build

BUILD_DIR="$HOME/pan-os-iso/build"

echo "═══════════════════════════════════════"
echo "  PanOS - Estado del Build"
echo "═══════════════════════════════════════"
echo ""

if [[ ! -d "$BUILD_DIR" ]]; then
    echo "❌ Directorio build no existe"
    echo "   Ejecuta: ./1-build.sh"
    exit 1
fi

echo "Verificando archivos..."
echo ""

# Verificar kernel
if [[ -f "$BUILD_DIR/vmlinuz" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/vmlinuz" | awk '{print $5}')
    echo "✅ Kernel (vmlinuz) .......... $SIZE"
else
    echo "❌ Kernel no encontrado"
fi

# Verificar initramfs
if [[ -f "$BUILD_DIR/initramfs.cpio" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/initramfs.cpio" | awk '{print $5}')
    echo "✅ Initramfs ................. $SIZE"
else
    echo "❌ Initramfs no encontrado"
fi

# Verificar Node.js
if cpio -t < "$BUILD_DIR/initramfs.cpio" 2>/dev/null | grep -q "^bin/node$"; then
    echo "✅ Node.js integrado"
else
    echo "⚠️  Node.js no encontrado"
fi

# Verificar npm
if cpio -t < "$BUILD_DIR/initramfs.cpio" 2>/dev/null | grep -q "^bin/npm$"; then
    echo "✅ npm integrado"
else
    echo "⚠️  npm no encontrado"
fi

# Verificar ISO
if [[ -f "$BUILD_DIR/pan-os-booteable.iso" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/pan-os-booteable.iso" | awk '{print $5}')
    echo "✅ ISO Booteable ............. $SIZE"
else
    echo "⚠️  ISO no creada (ejecuta: ./4-create-iso.sh)"
fi

echo ""
echo "═══════════════════════════════════════"
echo ""

if [[ -f "$BUILD_DIR/vmlinuz" ]] && [[ -f "$BUILD_DIR/initramfs.cpio" ]]; then
    echo "✓ Sistema listo para usar"
    echo ""
    echo "Siguiente paso:"
    echo "  ./2-run.sh         (ejecutar en QEMU)"
    echo "  ./4-create-iso.sh  (crear ISO booteable)"
else
    echo "❌ Build incompleto"
    echo "   Ejecuta: ./1-build.sh"
fi
