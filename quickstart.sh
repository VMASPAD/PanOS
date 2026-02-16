#!/bin/bash

#################################################################
# PanOS - Quick Start Script
# One command to create your OS
#################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                    PanOS QUICK START               ║"
echo "║         Greatest OS for Any Task - Pan OS Edition         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Detect script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check that build-PanOS-os.sh exists
if [ ! -f "${SCRIPT_DIR}/build-PanOS-os.sh" ]; then
    echo "❌ Error: build-PanOS-os.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

echo "📋 Checking prerequisites..."
echo "   running dependency verification..."
echo ""

# Run build script in automatic mode
"${SCRIPT_DIR}/build-PanOS-os.sh" --auto

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              ✅ BUILD COMPLETED SUCCESSFULLY              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "📍 Your PanOS is ready at: ~/pan-os/build/"
    echo ""
    echo "🚀 To run it again:"
    echo "   qemu-system-x86_64 \\"
    echo "     -kernel ~/pan-os/build/vmlinuz \\"
    echo "     -initrd ~/pan-os/build/initramfs.cpio \\"
    echo "     -nographic -append 'console=ttyS0' -m 512"
    echo ""
else
    echo ""
    echo "❌ Error during build"
    exit 1
fi
