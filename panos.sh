#!/bin/bash

#################################################################
# PanOS - Unified Build System
# Interactive menu for building, running, and managing PanOS
#################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${HOME}/pan-os-iso"
BUILD_DIR="${WORKSPACE}/build"
KERNEL_VERSION="6.6.15"

# Detect architecture
HOST_ARCH="$(uname -m)"

#################################################################
# Helper Functions
#################################################################

print_logo() {
    echo -e "${CYAN}"
    echo "  ____              ___  ____  "
    echo " |  _ \ __ _ _ __  / _ \/ ___| "
    echo " | |_) / _\` | '_ \| | | \___ \ "
    echo " |  __/ (_| | | | | |_| |___) |"
    echo " |_|   \__,_|_| |_|\___/|____/ "
    echo -e "${NC}"
    echo -e "${DIM}  Linux ${KERNEL_VERSION} + Busybox + Node.js v24${NC}"
    echo ""
}

print_separator() {
    echo -e "${BLUE}$(printf '%.0s─' {1..55})${NC}"
}

print_status() {
    local label="$1"
    local status="$2"
    if [[ "$status" == "ok" ]]; then
        printf "  ${GREEN}[OK]${NC}  %-40s\n" "$label"
    elif [[ "$status" == "missing" ]]; then
        printf "  ${RED}[--]${NC}  %-40s\n" "$label"
    elif [[ "$status" == "warn" ]]; then
        printf "  ${YELLOW}[!!]${NC}  %-40s\n" "$label"
    fi
}

check_build_status() {
    local has_kernel=false
    local has_initramfs=false
    local has_iso=false

    [[ -f "$BUILD_DIR/vmlinuz" ]] && has_kernel=true
    [[ -f "$BUILD_DIR/initramfs.cpio" ]] && has_initramfs=true
    [[ -f "$BUILD_DIR/pan-os-booteable.iso" ]] || [[ -f "$BUILD_DIR/pan-os.iso" ]] && has_iso=true

    echo ""
    echo -e "  ${BOLD}Build Status:${NC}"

    if $has_kernel; then
        local ksize=$(ls -lh "$BUILD_DIR/vmlinuz" 2>/dev/null | awk '{print $5}')
        print_status "Kernel (vmlinuz) ......... $ksize" "ok"
    else
        print_status "Kernel (vmlinuz)" "missing"
    fi

    if $has_initramfs; then
        local isize=$(ls -lh "$BUILD_DIR/initramfs.cpio" 2>/dev/null | awk '{print $5}')
        print_status "Initramfs ................ $isize" "ok"
    else
        print_status "Initramfs" "missing"
    fi

    if $has_iso; then
        local iso_file=""
        [[ -f "$BUILD_DIR/pan-os-booteable.iso" ]] && iso_file="$BUILD_DIR/pan-os-booteable.iso"
        [[ -f "$BUILD_DIR/pan-os.iso" ]] && iso_file="$BUILD_DIR/pan-os.iso"
        local isz=$(ls -lh "$iso_file" 2>/dev/null | awk '{print $5}')
        print_status "Bootable ISO ............. $isz" "ok"
    else
        print_status "Bootable ISO (optional)" "warn"
    fi

    echo ""
}

wait_for_key() {
    echo ""
    read -rp "  Press Enter to continue..." _
}

#################################################################
# Main Menu
#################################################################

show_main_menu() {
    clear
    print_logo
    print_separator
    echo -e "  ${BOLD}MAIN MENU${NC}                       arch: ${CYAN}${HOST_ARCH}${NC}"
    print_separator
    echo ""
    echo -e "  ${BOLD}Build${NC}"
    echo "    1)  Full build          (deps + kernel + rootfs + ISO)"
    echo "    2)  Install dependencies only"
    echo "    3)  Build kernel + rootfs only"
    echo "    4)  Create bootable ISO"
    echo ""
    echo -e "  ${BOLD}Run${NC}"
    echo "    5)  Run in QEMU (serial console)"
    echo "    6)  Run ISO in QEMU"
    echo ""
    echo -e "  ${BOLD}Docker${NC}"
    echo "    7)  Build & run with Docker Compose"
    echo "    8)  Build Docker image only"
    echo ""
    echo -e "  ${BOLD}Tools${NC}"
    echo "    9)  Check build status"
    echo "   10)  Clean build artifacts"
    echo "   11)  Build for ARM64 (aarch64)"
    echo ""
    echo -e "    ${DIM}q)  Quit${NC}"
    echo ""

    if [[ -f "$BUILD_DIR/vmlinuz" ]]; then
        check_build_status
    fi

    print_separator
}

#################################################################
# Actions
#################################################################

action_full_build() {
    echo ""
    echo -e "${BOLD}Full Build Pipeline${NC}"
    print_separator
    echo ""
    echo "This will:"
    echo "  1. Install host dependencies (needs sudo)"
    echo "  2. Download and compile Linux kernel ${KERNEL_VERSION}"
    echo "  3. Create rootfs with Busybox + Node.js v24"
    echo "  4. Package initramfs"
    echo "  5. Create bootable ISO with GRUB"
    echo ""
    read -rp "Continue? [Y/n] " confirm
    confirm=${confirm:-Y}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        return
    fi

    echo ""
    bash "${SCRIPT_DIR}/scripts/build/install-deps.sh"
    echo ""
    bash "${SCRIPT_DIR}/scripts/build/build-system.sh"
    echo ""
    bash "${SCRIPT_DIR}/scripts/iso/create-iso.sh"
    echo ""

    echo -e "${GREEN}${BOLD}Full build completed!${NC}"
    check_build_status
}

action_install_deps() {
    echo ""
    bash "${SCRIPT_DIR}/scripts/build/install-deps.sh"
}

action_build_system() {
    echo ""
    bash "${SCRIPT_DIR}/scripts/build/build-system.sh"
}

action_create_iso() {
    echo ""
    bash "${SCRIPT_DIR}/scripts/iso/create-iso.sh"
}

action_run_qemu() {
    echo ""
    bash "${SCRIPT_DIR}/scripts/run/run-qemu.sh"
}

action_run_iso() {
    echo ""
    if [[ -f "$BUILD_DIR/pan-os-booteable.iso" ]]; then
        ISO_FILE="$BUILD_DIR/pan-os-booteable.iso"
    elif [[ -f "$BUILD_DIR/pan-os.iso" ]]; then
        ISO_FILE="$BUILD_DIR/pan-os.iso"
    else
        echo -e "${RED}No ISO found. Run option 4 first.${NC}"
        return
    fi

    echo -e "Booting ISO: ${CYAN}$ISO_FILE${NC}"
    echo "Press Ctrl+A then X to exit QEMU"
    echo ""
    sleep 1
    qemu-system-x86_64 \
        -cdrom "$ISO_FILE" \
        -nographic -serial stdio -monitor none \
        -m 2048 -smp 2
}

action_docker_compose() {
    echo ""
    echo "Building and running PanOS with Docker Compose..."
    echo ""
    cd "${SCRIPT_DIR}"
    docker compose up --build
}

action_docker_build() {
    echo ""
    echo "Building PanOS Docker image..."
    echo ""
    cd "${SCRIPT_DIR}"
    docker build -t panos:latest .
    echo ""
    echo -e "${GREEN}Docker image built: panos:latest${NC}"
}

action_check_status() {
    echo ""
    bash "${SCRIPT_DIR}/scripts/utils/check-build.sh"
}

action_clean() {
    echo ""
    echo -e "${YELLOW}This will remove all build artifacts from:${NC}"
    echo "  ${WORKSPACE}/"
    echo ""
    read -rp "Continue? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "${WORKSPACE}"
        echo -e "${GREEN}Build artifacts cleaned.${NC}"
    else
        echo "Cancelled."
    fi
}

action_build_arm64() {
    echo ""
    bash "${SCRIPT_DIR}/scripts/build/build-arm64.sh"
}

#################################################################
# CLI argument handling
#################################################################

if [[ "${1:-}" == "--auto" ]] || [[ "${1:-}" == "-a" ]]; then
    print_logo
    action_full_build
    exit 0
fi

if [[ "${1:-}" == "--build" ]] || [[ "${1:-}" == "-b" ]]; then
    print_logo
    action_build_system
    exit 0
fi

if [[ "${1:-}" == "--run" ]] || [[ "${1:-}" == "-r" ]]; then
    action_run_qemu
    exit 0
fi

if [[ "${1:-}" == "--docker" ]] || [[ "${1:-}" == "-d" ]]; then
    action_docker_compose
    exit 0
fi

if [[ "${1:-}" == "--arm64" ]]; then
    action_build_arm64
    exit 0
fi

if [[ "${1:-}" == "--clean" ]] || [[ "${1:-}" == "-c" ]]; then
    action_clean
    exit 0
fi

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    print_logo
    echo "Usage: ./panos.sh [option]"
    echo ""
    echo "Options:"
    echo "  (none)      Interactive menu"
    echo "  --auto, -a  Full automatic build"
    echo "  --build, -b Build kernel + rootfs only"
    echo "  --run, -r   Run in QEMU"
    echo "  --docker, -d Build & run with Docker"
    echo "  --arm64     Build for ARM64"
    echo "  --clean, -c Clean build artifacts"
    echo "  --help, -h  Show this help"
    echo ""
    exit 0
fi

#################################################################
# Interactive Menu Loop
#################################################################

while true; do
    show_main_menu
    read -rp "  Select option: " choice

    case "$choice" in
        1)  action_full_build; wait_for_key ;;
        2)  action_install_deps; wait_for_key ;;
        3)  action_build_system; wait_for_key ;;
        4)  action_create_iso; wait_for_key ;;
        5)  action_run_qemu ;;
        6)  action_run_iso ;;
        7)  action_docker_compose ;;
        8)  action_docker_build; wait_for_key ;;
        9)  action_check_status; wait_for_key ;;
        10) action_clean; wait_for_key ;;
        11) action_build_arm64; wait_for_key ;;
        q|Q) echo ""; echo "Bye!"; exit 0 ;;
        *)  echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
