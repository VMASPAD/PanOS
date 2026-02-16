#!/bin/bash

# PanOS - Check Build Status

BUILD_DIR="$HOME/pan-os-iso/build"

echo "═══════════════════════════════════════"
echo "  PanOS - Build Status"
echo "═══════════════════════════════════════"
echo ""

if [[ ! -d "$BUILD_DIR" ]]; then
    echo "❌ Build directory does not exist"
    echo "   Run: ./1-build.sh"
    exit 1
fi

echo "Checking files..."
echo ""

# Check kernel
if [[ -f "$BUILD_DIR/vmlinuz" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/vmlinuz" | awk '{print $5}')
    echo "✅ Kernel (vmlinuz) .......... $SIZE"
else
    echo "❌ Kernel not found"
fi

# Check initramfs
if [[ -f "$BUILD_DIR/initramfs.cpio" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/initramfs.cpio" | awk '{print $5}')
    echo "✅ Initramfs ................. $SIZE"
else
    echo "❌ Initramfs not found"
fi

# Check Node.js
if cpio -t < "$BUILD_DIR/initramfs.cpio" 2>/dev/null | grep -q "^bin/node$"; then
    echo "✅ Node.js integrated"
else
    echo "⚠️  Node.js not found"
fi

# Check npm
if cpio -t < "$BUILD_DIR/initramfs.cpio" 2>/dev/null | grep -q "^bin/npm$"; then
    echo "✅ npm integrated"
else
    echo "⚠️  npm not found"
fi

# Check ISO
if [[ -f "$BUILD_DIR/pan-os-booteable.iso" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/pan-os-booteable.iso" | awk '{print $5}')
    echo "✅ Bootable ISO ............. $SIZE"
else
    echo "⚠️  ISO not created (run: ./4-create-iso.sh)"
fi

echo ""
echo "═══════════════════════════════════════"
echo ""

if [[ -f "$BUILD_DIR/vmlinuz" ]] && [[ -f "$BUILD_DIR/initramfs.cpio" ]]; then
    echo "✓ System ready to use"
    echo ""
    echo "Next step:"
    echo "  ./2-run.sh         (run in QEMU)"
    echo "  ./4-create-iso.sh  (create bootable ISO)"
else
    echo "❌ Build incomplete"
    echo "   Run: ./1-build.sh"
fi
