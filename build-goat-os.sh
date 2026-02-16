#!/bin/bash

#################################################################
# PanOS Build Script
# Crea un sistema operativo minimalista con Linux Kernel + NodeJS
#################################################################

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuracion
KERNEL_VERSION="6.6.15"
WORKSPACE_DIR="${HOME}/pan-os"
KERNEL_DIR="${WORKSPACE_DIR}/kernel-src"
ROOTFS_DIR="${WORKSPACE_DIR}/rootfs"
BUILD_DIR="${WORKSPACE_DIR}/build"
QEMU_RAM="512"
QEMU_CPU="2"

#################################################################
# Funciones Helper
#################################################################

print_header() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_dependencies() {
    print_header "Verificando Dependencies"
    
    local required_tools=("gcc" "make" "bison" "flex" "wget" "unzip" "cpio" "qemu-system-x86_64")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        else
            print_success "$tool instalado"
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Herramientas faltantes: ${missing_tools[*]}"
        print_warning "Instala con: sudo apt install build-essential bison flex libncurses-dev libssl-dev bc cpio wget unzip qemu-system-x86_64"
        return 1
    fi
    
    print_success "Todas las Dependencies estan instaladas"
}

setup_workspace() {
    print_header "Configurando espacio de trabajo"
    
    mkdir -p "${WORKSPACE_DIR}"/{kernel-src,rootfs,build}
    cd "${WORKSPACE_DIR}"
    
    print_success "Directorys creados en: ${WORKSPACE_DIR}"
}

download_kernel() {
    print_header "Downloading Kernel Linux ${KERNEL_VERSION}"
    
    if [ -d "${KERNEL_DIR}/linux-${KERNEL_VERSION}" ]; then
        print_warning "Kernel ya existe, saltando descarga"
        return 0
    fi
    
    cd "${KERNEL_DIR}"
    
    local kernel_url="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
    print_warning "Downloading desde: ${kernel_url}"
    
    if ! wget -q "${kernel_url}"; then
        print_error "Error descargando kernel"
        return 1
    fi
    
    tar -xf "linux-${KERNEL_VERSION}.tar.xz"
    print_success "Kernel descargado y extraido"
}

configure_kernel() {
    print_header "Configurando Kernel (minimal pero funcional)"
    
    cd "${KERNEL_DIR}/linux-${KERNEL_VERSION}"
    
    # Limpiar
    make mrproper > /dev/null 2>&1
    
    # Usar allnoconfig como base y agregar lo esencial
    make allnoconfig > /dev/null 2>&1
    
    # Configuracion ESENCIAL para que funcione
    cat > .config << 'EOF'
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_CORE=y
CONFIG_SERIAL_CORE_CONSOLE=y
CONFIG_CONSOLE_LOGLEVEL_DEFAULT=7
CONFIG_EARLY_PRINTK=y
CONFIG_PRINTK=y
CONFIG_PRINTK_TIME=y

# Filesystem
CONFIG_EXT4_FS=y
CONFIG_VFATs=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y

# Executables
CONFIG_BINFMT_ELF=y
CONFIG_BINFMT_SCRIPT=y

# Boot
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y

# Hardware
CONFIG_PCI=y
CONFIG_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_CONSOLE=y

# Block
CONFIG_ATA=y
CONFIG_ATA_GENERIC=y

# Networking minimal
CONFIG_NET=y
CONFIG_INET=y
CONFIG_UNIX=y

# Basic system
CONFIG_KCONFIG_DEBUG=y
CONFIG_BUILTIN_DTFS=y
EOF
    
    # Aplicar las opciones
    make oldconfig < /dev/null > /dev/null 2>&1
    
    print_success "Kernel configurado (base minima funcional)"
}

compile_kernel() {
    print_header "Compiling Kernel (esto puede tomar varios minutos)"
    
    cd "${KERNEL_DIR}/linux-${KERNEL_VERSION}"
    
    local cpu_count=$(nproc)
    print_warning "Usando ${cpu_count} CPUs para compilar"
    
    make -j"${cpu_count}" > /tmp/kernel_build.log 2>&1
    
    if [ ! -f "arch/x86/boot/bzImage" ]; then
        print_error "Compilationon del kernel fallo. Ver: /tmp/kernel_build.log"
        return 1
    fi
    
    cp arch/x86/boot/bzImage "${BUILD_DIR}/vmlinuz"
    print_success "Kernel compilado: ${BUILD_DIR}/vmlinuz"
}

setup_rootfs() {
    print_header "Configurando RootFS"
    
    cd "${ROOTFS_DIR}"
    
    # Create estructura de Directorys
    mkdir -p bin dev etc lib proc sbin sys tmp root \
             usr/bin usr/lib usr/sbin var/lib var/log boot
    
    print_success "Estructura de Directorys creada"
}

download_busybox() {
    print_header "Downloading Busybox (musl estatico)"
    
    cd "${ROOTFS_DIR}"
    
    if [ -f "bin/busybox" ]; then
        print_warning "Busybox ya existe, saltando"
        return 0
    fi
    
    local busybox_url="https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox"
    
    if ! wget -q "${busybox_url}" -O bin/busybox; then
        # Alternativa: usar version de AppImage
        print_warning "Intentando descargar desde AppImage"
        wget -q https://github.com/mirror/busybox/releases/download/1.35.0/busybox-x86_64 -O bin/busybox || {
            print_error "No se pudo descargar Busybox"
            return 1
        }
    fi
    
    chmod +x bin/busybox
    
    # Create enlazces simbolicos
    cd bin
    ./busybox --install . > /dev/null 2>&1
    cd ..
    
    print_success "Busybox instalado y enlaces simbolicos creados"
}

download_NodeJS() {
    print_header "Downloading NodeJS (version musl)"
    
    cd "${ROOTFS_DIR}"
    
    if [ -f "bin/NodeJS" ]; then
        print_warning "NodeJS ya existe, saltando"
        return 0
    fi
    
    # Intentamos descargar NodeJS musl
    local NodeJS_url="https://github.com/oven-sh/NodeJS/releases/download/NodeJS-v1.0.0/NodeJS-linux-x64-musl.zip"
    
    print_warning "Downloading NodeJS desde: ${NodeJS_url}"
    print_warning "Nota: Asegurate de tener suficiente espacio (>100MB)"
    
    if wget -q "${NodeJS_url}" -O /tmp/NodeJS.zip; then
        unzip -q /tmp/NodeJS.zip -d /tmp
        if [ -f "/tmp/NodeJS-linux-x64-musl/NodeJS" ]; then
            mv /tmp/NodeJS-linux-x64-musl/NodeJS bin/
            rm -rf /tmp/NodeJS*
            chmod +x bin/NodeJS
            print_success "NodeJS instalado"
        else
            print_warning "Estructura de NodeJS not foundada, intentando alternativa"
            # Si falla, intentamos con version glibc (puede no funcionar en alpine pero lo intentamos)
            return 0
        fi
    else
        print_warning "No se pudo descargar NodeJS automaticamente"
        print_warning "Descargalo manualmente de: https://github.com/oven-sh/NodeJS/releases"
        print_warning "Y colocalo en: ${ROOTFS_DIR}/bin/NodeJS"
        return 0
    fi
}

create_init_script() {
    print_header "Creating script de inicializacion (/init)"
    
    cat > "${ROOTFS_DIR}/init" << 'INIT_EOF'
#!/bin/busybox sh

exec 2>&1

# Montar sistemas de files
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t devtmpfs devtmpfs /dev
/bin/busybox mount -t tmpfs tmpfs /tmp

# Create dispositivos criticos
[ -e /dev/console ] || /bin/busybox mknod /dev/console c 5 1
[ -e /dev/tty ] || /bin/busybox mknod /dev/tty c 5 0
[ -e /dev/null ] || /bin/busybox mknod /dev/null c 1 3
[ -e /dev/zero ] || /bin/busybox mknod /dev/zero c 1 5

# Mensaje de bienvenida
echo ""
echo "╔════════════════════════════════════════╗"
echo "║   🚀 PanOS - Terminal Shell     ║"
echo "║   Linux 6.6 + Busybox                 ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Comandos disponibles: ls, ps, free, df, cat, echo, grep, sed, awk, etc."
echo "Escribe 'exit' para apagar el OS"
echo ""

# Lanzar shell interactiva directamente
exec /bin/busybox sh

INIT_EOF

    chmod +x "${ROOTFS_DIR}/init"
    print_success "Script init creado (shell interactiva directo)"
}

create_boot_script() {
    print_header "Creating script de boot (/boot.js)"
    
    cat > "${ROOTFS_DIR}/boot.js" << 'BOOT_EOF'
#!/usr/bin/NodeJS

// Boot script para PanOS
// (No se usa en esta configuracion - init lanza shell directo)

console.log("🚀 PanOS Boot");

BOOT_EOF

    chmod +x "${ROOTFS_DIR}/boot.js"
    print_success "Script boot.js creado (minimo)"
}

create_initramfs() {
    print_header "Packageando RootFS en initramfs"
    
    cd "${ROOTFS_DIR}"
    
    # Create CPIO
    find . -print0 | cpio -0 -o -H newc > "${BUILD_DIR}/initramfs.cpio" 2>/dev/null
    
    if [ ! -f "${BUILD_DIR}/initramfs.cpio" ]; then
        print_error "Error creando initramfs"
        return 1
    fi
    
    local size=$(du -h "${BUILD_DIR}/initramfs.cpio" | cut -f1)
    print_success "Initramfs creado: ${size} (${BUILD_DIR}/initramfs.cpio)"
}

build_summary() {
    print_header "📦 Resumen de la Construccion"
    
    echo -e "${GREEN}Archivos generated:${NC}"
    ls -lh "${BUILD_DIR}"/
    
    echo ""
    echo -e "${GREEN}Para ejecutar PanOS:${NC}"
    echo ""
    echo "qemu-system-x86_64 \\"
    echo "  -kernel ${BUILD_DIR}/vmlinuz \\"
    echo "  -initrd ${BUILD_DIR}/initramfs.cpio \\"
    echo "  -nographic \\"
    echo "  -serial stdio \\"
    echo "  -append \"console=ttyS0 loglevel=3\" \\"
    echo "  -m ${QEMU_RAM} \\"
    echo "  -smp ${QEMU_CPU} \\"
    echo "  -monitor none"
    echo ""
}

run_qemu() {
    print_header "🖥️  Runndo en QEMU"
    
    if [ ! -f "${BUILD_DIR}/vmlinuz" ] || [ ! -f "${BUILD_DIR}/initramfs.cpio" ]; then
        print_error "Archivos de imagen not foundados"
        return 1
    fi
    
    print_warning "Iniciando maquina virtual..."
    print_warning "Presiona Ctrl+A luego X para salir de QEMU"
    echo ""
    
    qemu-system-x86_64 \
      -kernel "${BUILD_DIR}/vmlinuz" \
      -initrd "${BUILD_DIR}/initramfs.cpio" \
      -nographic \
      -serial stdio \
      -append "console=ttyS0 loglevel=3" \
      -m "${QEMU_RAM}" \
      -smp "${QEMU_CPU}" \
      -monitor none
}

#################################################################
# Main Menu
#################################################################

show_menu() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        PanOS Build System        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "1) Check Dependencies"
    echo "2) Configurar workspace"
    echo "3) Descargar kernel"
    echo "4) Configurar kernel"
    echo "5) Compilar kernel"
    echo "6) Create rootfs"
    echo "7) Install Busybox"
    echo "8) Install NodeJS"
    echo "9) Create scripts de init/boot"
    echo "10) Packagear initramfs"
    echo "11) Ver resumen"
    echo "12) Run in QEMU"
    echo ""
    echo "0) Runr construccion COMPLETA (todos los pasos)"
    echo "q) Salir"
    echo ""
}

full_build() {
    print_header "🔨 Iniciando construccion COMPLETA de PanOS"
    
    check_dependencies || exit 1
    setup_workspace || exit 1
    download_kernel || exit 1
    configure_kernel || exit 1
    compile_kernel || exit 1
    setup_rootfs || exit 1
    download_busybox || exit 1
    download_NodeJS || exit 1
    create_init_script || exit 1
    create_boot_script || exit 1
    create_initramfs || exit 1
    build_summary
    
    echo ""
    read -p "¿Deseas ejecutar en QEMU ahora? (s/n): " -n 1 -r run_qemu
    echo ""
    if [[ $run_qemu =~ ^[Ss]$ ]]; then
        run_qemu
    fi
}

#################################################################
# Script Principal
#################################################################

main() {
    if [ "$1" == "--auto" ]; then
        full_build
        return
    fi
    
    while true; do
        show_menu
        read -p "Elige una opcion: " choice
        
        case $choice in
            1) check_dependencies ;;
            2) setup_workspace ;;
            3) download_kernel ;;
            4) configure_kernel ;;
            5) compile_kernel ;;
            6) setup_rootfs ;;
            7) download_busybox ;;
            8) download_NodeJS ;;
            9) create_init_script && create_boot_script ;;
            10) create_initramfs ;;
            11) build_summary ;;
            12) run_qemu ;;
            0) full_build && break ;;
            q) 
                echo "Saliendo..."
                exit 0
                ;;
            *)
                print_error "Opcion invalida"
                ;;
        esac
        
        read -p "Presiona Enter para continuar..."
    done
}

main "$@"
