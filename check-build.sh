#!/bin/bash

# Estado actual del build y pasos nexts

BUILD_DIR="$HOME/pan-os-iso/build"

cat << 'EOF'

╔════════════════════════════════════════════════════════════════════════════╗
║                   ESTADO DEL BUILD DE PanOS                        ║
╚════════════════════════════════════════════════════════════════════════════╝

VERIFICANDO ARCHIVOS GENERADOS...

EOF

echo ""
if [[ -f "$BUILD_DIR/vmlinuz" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/vmlinuz" | awk '{print $5}')
    echo "✅ vmlinuz (Kernel Linux)............ $SIZE"
else
    echo "❌ vmlinuz.............................. NO ENCONTRADO"
fi

if [[ -f "$BUILD_DIR/initramfs.cpio" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/initramfs.cpio" | awk '{print $5}')
    echo "✅ initramfs.cpio (Sistema raiz).... $SIZE"
else
    echo "❌ initramfs.cpio...................... NO ENCONTRADO"
fi

if [[ -f "$BUILD_DIR/PanOS-os.iso" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/PanOS-os.iso" | awk '{print $5}')
    echo "✅ PanOS-os.iso (Imagen booteable)... $SIZE"
else
    echo "❌ PanOS-os.iso......................... NO ENCONTRADO"
fi

if [[ -f "$BUILD_DIR/rootfs/bin/NodeJS" ]]; then
    SIZE=$(ls -lh "$BUILD_DIR/rootfs/bin/NodeJS" | awk '{print $5}')
    echo "✅ /bin/NodeJS (Runtime)................ $SIZE"
else
    echo "❌ /bin/NodeJS............................ NO ENCONTRADO"
fi

if [[ -f "$BUILD_DIR/rootfs/boot.js" ]]; then
    echo "✅ boot.js (Script for inicio)........ PRESENTE"
else
    echo "❌ boot.js............................ NO ENCONTRADO"
fi

echo ""
cat << 'EOF'

════════════════════════════════════════════════════════════════════════════

PROXIMOS PASOS:

1️⃣  SI VES ❌ EN MIEMBROS CRITICOS (vmlinuz, initramfs.cpio):
    
    $ ./build-iso-with-NodeJS.sh
    
    El script se ejecutara nuevamente. Toma 15-30 minutos.

════════════════════════────────────────────────────────────────────────════

2️⃣  SI TODO MUESTRA ✅ :

    $ ./run-iso.sh
    
    Elige opcion 1 para ISO o 2 para initramfs (mas rapido)
    El OS deberia arrancar en QEMU

════════════════────────────────────────────────────════════════════════════

3️⃣  DENTRO DEL OS (cuando veas el prompt):

    # NodeJS --version
    # NodeJS boot.js
    # NodeJS eval "console.log('¡Hola JavaScript!')"

════════════════════════════════════════════════════════════════════════════

EOF

echo ""
ls -lah "$BUILD_DIR" 2>/dev/null | tail -n +4 || echo "Directory not foundado. Run first: ./build-iso-with-NodeJS.sh"
