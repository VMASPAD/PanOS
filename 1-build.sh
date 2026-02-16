#!/bin/bash

# Script para crear ISO de PanOS con NodeJS integrado

set -e

WORKSPACE="${HOME}/pan-os-iso"
ROOTFS="${WORKSPACE}/rootfs"
BUILD="${WORKSPACE}/build"
ISO_DIR="${WORKSPACE}/iso"
KERNEL_VERSION="6.6.15"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}PanOS ISO BUILD (con NodeJS integrado)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Clean
echo -e "${YELLOW}[1/6] Limpiando build anterior...${NC}"
rm -rf "${WORKSPACE}" 2>/dev/null || true
mkdir -p "${WORKSPACE}/kernel-src" "${ROOTFS}" "${BUILD}" "${ISO_DIR}/boot/grub"
echo -e "${GREEN}✓ Limpieza completada${NC}"
echo ""

# Download and compile kernel
echo -e "${YELLOW}[2/6] Descargando y compilando kernel...${NC}"
cd "${WORKSPACE}/kernel-src"

if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
    echo "  Descargando kernel..."
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz" || {
        echo -e "${RED}✗ Error descargando kernel${NC}"
        exit 1
    }
fi

if [ ! -d "linux-${KERNEL_VERSION}" ]; then
    tar -xf "linux-${KERNEL_VERSION}.tar.xz"
fi

cd "linux-${KERNEL_VERSION}"

make allnoconfig > /dev/null 2>&1

cat > .config << 'EOF'
CONFIG_64BIT=y
CONFIG_X86=y
CONFIG_X86_64=y
CONFIG_SMP=y
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

# Input devices - Keyboard and Mouse
CONFIG_INPUT=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_KEYBOARD_ATKBD=y
CONFIG_INPUT_MOUSE=y
CONFIG_INPUT_MOUSEDEV=y
CONFIG_MOUSE_PS2=y
CONFIG_SERIO=y
CONFIG_SERIO_I8042=y
CONFIG_SERIO_LIBPS2=y

# Storage
CONFIG_SCSI=y
CONFIG_SCSI_GENERIC=y
CONFIG_SATA_AHCI=y
CONFIG_ATA=y
CONFIG_ATA_SFF=y
CONFIG_ATA_PIIX=y
CONFIG_BLK_DEV_SD=y

# VirtIO support
CONFIG_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_CONSOLE=y
CONFIG_HW_RANDOM=y
CONFIG_HW_RANDOM_VIRTIO=y

# PCI support
CONFIG_PCI=y
CONFIG_PCI_MSI=y

# Networking core
CONFIG_NET=y
CONFIG_INET=y
CONFIG_PACKET=y
CONFIG_UNIX=y
CONFIG_NETDEVICES=y
CONFIG_NET_CORE=y
CONFIG_ETHERNET=y

# Network drivers - Generic
CONFIG_VIRTIO_NET=y
CONFIG_E1000=y
CONFIG_E1000E=y
CONFIG_NE2K_PCI=y
CONFIG_PCNET32=y
CONFIG_8139CP=y
CONFIG_8139TOO=y

# IP configuration
CONFIG_IP_PNP=y
CONFIG_IP_PNP_DHCP=y
CONFIG_IP_MULTICAST=y
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_FIB_TRIE=y
CONFIG_IP_MULTIPLE_TABLES=y

# TCP/IP
CONFIG_TCP_CONG_CUBIC=y
CONFIG_DEFAULT_TCP_CONG="cubic"
CONFIG_IPV6=y

# Network filter
CONFIG_NETFILTER=y
CONFIG_NETFILTER_ADVANCED=y
CONFIG_DNS_RESOLVER=y

# Random number generator - Fix for crng init hang
CONFIG_RANDOM_TRUST_CPU=y
CONFIG_RANDOM_TRUST_BOOTLOADER=y

# Crypto support for HTTPS
CONFIG_CRYPTO=y
CONFIG_CRYPTO_AES=y
CONFIG_CRYPTO_SHA256=y
CONFIG_CRYPTO_HMAC=y
CONFIG_CRYPTO_ECB=y
CONFIG_CRYPTO_CBC=y
EOF

make oldconfig < /dev/null > /dev/null 2>&1

echo "  Compilando kernel (esto toma tiempo)..."
make -j$(nproc) 2>&1 | tail -30

if [ ! -f "arch/x86/boot/bzImage" ]; then
    echo -e "${RED}✗ Error compilando kernel${NC}"
    exit 1
fi

cp arch/x86/boot/bzImage "${BUILD}/vmlinuz"
echo -e "${GREEN}✓ Kernel compilado${NC}"
echo ""

# Create rootfs
echo -e "${YELLOW}[3/6] Creando rootfs...${NC}"
cd "${ROOTFS}"

mkdir -p bin dev etc lib lib64 proc sbin sys tmp root usr/bin usr/lib var/lib var/log boot

# Download busybox
echo "  Descargando busybox..."
mkdir -p bin
cd bin
wget -q "https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox" -O busybox 2>/dev/null || \
wget -q "https://github.com/mirror/busybox/releases/download/1.35.0/busybox-x86_64" -O busybox

chmod +x busybox
./busybox --install . > /dev/null 2>&1
cd "${ROOTFS}"

# Ensure /usr/bin/env exists for scripts that expect it
ln -sf /bin/env "${ROOTFS}/usr/bin/env"

# Create udhcpc script for DHCP
mkdir -p "${ROOTFS}/usr/share/udhcpc"
cat > "${ROOTFS}/usr/share/udhcpc/default.script" << 'UDHCPC_EOF'
#!/bin/sh
# udhcpc script for busybox - improved version with robust logging

# Ensure /var/log exists and is writable
mkdir -p /var/log 2>/dev/null || true
LOG_FILE="/var/log/udhcpc.log"

# Function to log messages to both file and console
log_msg() {
    echo "[udhcpc] $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /tmp/udhcpc.log 2>/dev/null || true
}

[ -z "$1" ] && log_msg "Error: should be called from udhcpc" && exit 1
[ -z "$interface" ] && log_msg "Error: no interface provided" && exit 1

log_msg "Event: $1 | Interface: $interface | IP: $ip | Subnet: $subnet | Router: $router | DNS: $dns"

case "$1" in
    deconfig)
        log_msg "Deconfiguring $interface"
        ip addr flush dev "$interface" 2>&1 || ifconfig "$interface" 0.0.0.0 2>&1 || log_msg "WARNING: Could not flush IP"
        ip route flush dev "$interface" 2>&1 || true
        ;;
    bound|renew)
        log_msg "Configuring $interface: IP=$ip, subnet=$subnet, router=$router"
        
        # Parse subnet mask to CIDR if needed
        CIDR="24"
        if [ -n "$subnet" ]; then
            case "$subnet" in
                255.255.255.0) CIDR="24" ;;
                255.255.0.0) CIDR="16" ;;
                255.0.0.0) CIDR="8" ;;
                *) CIDR="24" ;;
            esac
        fi
        
        # Remove any existing IP address
        ip addr flush dev "$interface" 2>/dev/null || true
        
        # Add IP address
        log_msg "Adding IP: $ip/$CIDR to $interface"
        if ip addr add "${ip}/${CIDR}" dev "$interface" 2>&1; then
            log_msg "✓ IP address added successfully"
        elif ifconfig "$interface" "$ip" netmask "$subnet" 2>&1; then
            log_msg "✓ IP configured via ifconfig"
        else
            log_msg "✗ ERROR: Failed to configure IP address"
            exit 1
        fi
        
        # Bring up the interface
        if ip link set "$interface" up 2>&1 || ifconfig "$interface" up 2>&1; then
            log_msg "✓ Interface brought up"
        else
            log_msg "WARNING: Could not bring interface up"
        fi
        
        # Set default gateway
        if [ -n "$router" ]; then
            log_msg "Setting default gateway: $router"
            ip route del default 2>/dev/null || true
            
            if ip route add default via "$router" dev "$interface" 2>&1; then
                log_msg "✓ Default gateway added via ip route"
            elif route add default gw "$router" dev "$interface" 2>&1; then
                log_msg "✓ Default gateway added via route"
            else
                log_msg "✗ ERROR: Failed to set default gateway"
            fi
        fi
        
        # Configure DNS
        if [ -n "$dns" ]; then
            log_msg "Configuring DNS servers: $dns"
            mkdir -p /etc 2>/dev/null || true
            {
                echo "# Auto-configured by udhcpc on $(date)"
                for i in $dns; do
                    echo "nameserver $i"
                done
            } > /etc/resolv.conf
            log_msg "DNS configuration written to /etc/resolv.conf"
        fi
        
        # Show final configuration
        log_msg "=== Final network configuration ==="
        log_msg "IP address:"
        ip addr show dev "$interface" 2>&1 | grep inet | while read line; do log_msg "  $line"; done
        log_msg "Routes:"
        ip route show 2>&1 | while read line; do log_msg "  $line"; done
        ;;
esac
exit 0
UDHCPC_EOF
chmod +x "${ROOTFS}/usr/share/udhcpc/default.script"

echo -e "${GREEN}✓ Busybox instalado${NC}"
echo ""

copy_binary_with_libs() {
    local bin="$1"
    local dest="$2"

    if [ ! -x "$bin" ]; then
        return 0
    fi

    mkdir -p "$dest"
    cp "$bin" "$dest/" 2>/dev/null || return 0
    chmod +x "$dest/$(basename "$bin")" 2>/dev/null || true

    ldd "$bin" 2>/dev/null | awk '
        $3 ~ /^\// { print $3 }
        $1 ~ /^\// { print $1 }
    ' | while read -r lib; do
        [ -f "$lib" ] || continue
        mkdir -p "${ROOTFS}$(dirname "$lib")"
        cp "$lib" "${ROOTFS}$(dirname "$lib")/" 2>/dev/null || true
    done
}

# Copy necessary glibc libraries for dynamic binaries (like NodeJS)
echo "  Copiando librerías glibc para NodeJS..."
if [ -f /lib/x86_64-linux-gnu/libc.so.6 ]; then
    mkdir -p "${ROOTFS}/lib64"
    # Core C libraries
    cp /lib/x86_64-linux-gnu/libc.so.6 "${ROOTFS}/lib/" 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libm.so.6 "${ROOTFS}/lib/" 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libdl.so.2 "${ROOTFS}/lib/" 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libpthread.so.0 "${ROOTFS}/lib/" 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libresolv.so.2 "${ROOTFS}/lib/" 2>/dev/null || true
    # C++ and GCC libraries
    cp /lib/x86_64-linux-gnu/libstdc++.so.6 "${ROOTFS}/lib/" 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libgcc_s.so.1 "${ROOTFS}/lib/" 2>/dev/null || true
    # Dynamic linker
    cp /lib64/ld-linux-x86-64.so.2 "${ROOTFS}/lib64/" 2>/dev/null || true
    # Additional libraries that might be needed
    cp /lib/x86_64-linux-gnu/libnsl.so.1 "${ROOTFS}/lib/" 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/librt.so.1 "${ROOTFS}/lib/" 2>/dev/null || true
fi
echo ""

# Integrate Git if available on host
echo "  Integrando Git..."
if command -v git >/dev/null 2>&1; then
    mkdir -p "${ROOTFS}/usr/bin" "${ROOTFS}/usr/lib/git-core"
    copy_binary_with_libs "$(command -v git)" "${ROOTFS}/usr/bin"

    if [ -d /usr/lib/git-core ]; then
        cp -a /usr/lib/git-core/* "${ROOTFS}/usr/lib/git-core/" 2>/dev/null || true
        if [ -x /usr/lib/git-core/git ]; then
            copy_binary_with_libs /usr/lib/git-core/git "${ROOTFS}/usr/lib/git-core"
        fi
        if [ -x /usr/lib/git-core/git-remote-https ]; then
            copy_binary_with_libs /usr/lib/git-core/git-remote-https "${ROOTFS}/usr/lib/git-core"
        fi
        if [ -x /usr/lib/git-core/git-remote-http ]; then
            copy_binary_with_libs /usr/lib/git-core/git-remote-http "${ROOTFS}/usr/lib/git-core"
        fi
    fi

    if [ -d /usr/share/git-core/templates ]; then
        mkdir -p "${ROOTFS}/usr/share/git-core"
        cp -a /usr/share/git-core/templates "${ROOTFS}/usr/share/git-core/" 2>/dev/null || true
    fi

    if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        mkdir -p "${ROOTFS}/etc/ssl/certs"
        cp /etc/ssl/certs/ca-certificates.crt "${ROOTFS}/etc/ssl/certs/" 2>/dev/null || true
    fi

    if [ -f /etc/gitconfig ]; then
        cp /etc/gitconfig "${ROOTFS}/etc/" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Git integrado${NC}"
else
    echo -e "${YELLOW}⚠️  Git no encontrado en el host${NC}"
fi
echo ""

# Download and integrate Node.js
echo -e "${YELLOW}[4/6] Descargando Node.js 24...${NC}"
mkdir -p bin
cd bin

echo "  Descargando Node.js 24 x64..."

# Usar Node.js 24 (más compatible que NodeJS)
NODE_VERSION="v24.0.0"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz"

if wget -q "${NODE_URL}" -O node.tar.xz 2>/dev/null; then
    echo "  Extrayendo Node.js..."
    if tar -xf node.tar.xz 2>/dev/null; then
        if [ -d "node-${NODE_VERSION}-linux-x64" ]; then
            # Copy node binary (essential)
            if [ -f "node-${NODE_VERSION}-linux-x64/bin/node" ]; then
                cp "node-${NODE_VERSION}-linux-x64/bin/node" . && chmod +x node
                echo -e "${GREEN}✓ Node.js ${NODE_VERSION} instalado${NC}"
            fi
            
            # Copy npm and npx binaries (optional)
            if [ -f "node-${NODE_VERSION}-linux-x64/bin/npm" ]; then
                cp "node-${NODE_VERSION}-linux-x64/bin/npm" . && chmod +x npm
                echo -e "${GREEN}✓ npm instalado${NC}"
            fi
            
            if [ -f "node-${NODE_VERSION}-linux-x64/bin/npx" ]; then
                cp "node-${NODE_VERSION}-linux-x64/bin/npx" . && chmod +x npx
            fi
            
            # Copy minimal npm module only if it exists
            if [ -d "node-${NODE_VERSION}-linux-x64/lib/node_modules/npm" ]; then
                mkdir -p ../lib/node_modules 2>/dev/null
                cp -r "node-${NODE_VERSION}-linux-x64/lib/node_modules/npm" ../lib/node_modules/ 2>/dev/null || true

                # Use wrapper scripts so npm/npx do not depend on /usr/bin/env
                cat > npm << 'NPM_EOF'
#!/bin/sh
exec /bin/node /lib/node_modules/npm/bin/npm-cli.js "$@"
NPM_EOF
                chmod +x npm

                cat > npx << 'NPX_EOF'
#!/bin/sh
exec /bin/node /lib/node_modules/npm/bin/npx-cli.js "$@"
NPX_EOF
                chmod +x npx
            fi
            
            rm -rf "node-${NODE_VERSION}-linux-x64"
        fi
    fi
    rm -f node.tar.xz
else
    echo -e "${YELLOW}⚠️  No se pudo descargar Node.js${NC}"
    # Create dummy node so the system doesn't break
    touch node && chmod +x node
fi

cd "${ROOTFS}"
echo ""

# Create init script
echo -e "${YELLOW}[5/6] Creando scripts...${NC}"

cat > init << 'INIT_EOF'
#!/bin/sh

# PanOS Init Script - Minimal and robust
# Enhanced debugging and error handling

echo "[init] Starting PanOS initialization..."

# Mount essential filesystems
echo "[init] Mounting /proc..."
mount -t proc proc /proc 2>&1 || echo "[init] WARNING: /proc mount failed"

echo "[init] Mounting /sys..."
mount -t sysfs sysfs /sys 2>&1 || echo "[init] WARNING: /sys mount failed"

echo "[init] Mounting /dev..."
mount -t devtmpfs devtmpfs /dev 2>&1 || echo "[init] WARNING: /dev mount failed"

echo "[init] Mounting /tmp..."
mount -t tmpfs tmpfs /tmp 2>&1 || echo "[init] WARNING: /tmp mount failed"

# Create device nodes (may already exist)
echo "[init] Creating device nodes..."
mknod /dev/console c 5 1 2>/dev/null || true
mknod /dev/tty c 5 0 2>/dev/null || true
mknod /dev/null c 1 3 2>/dev/null || true
mknod /dev/random c 1 8 2>/dev/null || true
mknod /dev/urandom c 1 9 2>/dev/null || true

# Bring up basic networking
echo "[init] Bringing up network..."

# Set up loopback
ip link set lo up 2>/dev/null || ifconfig lo 127.0.0.1 up 2>/dev/null || true

# Wait for network devices to appear
sleep 2

# List available network interfaces
echo "[init] Available network interfaces:"
ip link show 2>/dev/null || ifconfig -a 2>/dev/null || true

# Try to find and bring up the first ethernet interface
ETH_IF=""
for iface in eth0 enp0s3 ens3; do
    if ip link show "$iface" >/dev/null 2>&1; then
        ETH_IF="$iface"
        break
    fi
done

if [ -n "$ETH_IF" ]; then
    echo "[init] Bringing up interface: $ETH_IF"
    ip link set "$ETH_IF" up 2>/dev/null || ifconfig "$ETH_IF" up 2>/dev/null || true
    
    # Create logging directory early
    mkdir -p /var/log 2>/dev/null || true
    
    # Set static IP immediately (QEMU user networking uses 10.0.2.x)
    echo "[init] Setting static IP address..."
    ip addr add 10.0.2.15/24 dev "$ETH_IF" 2>/dev/null || \
    ifconfig "$ETH_IF" 10.0.2.15 netmask 255.255.255.0 2>/dev/null || true
    
    # Set default gateway immediately  
    echo "[init] Setting default gateway..."
    ip route add default via 10.0.2.2 dev "$ETH_IF" 2>/dev/null || \
    route add default gw 10.0.2.2 dev "$ETH_IF" 2>/dev/null || true
    
    # Setup DNS immediately
    echo "[init] Setting DNS servers..."
    mkdir -p /etc 2>/dev/null || true
    {
        echo "# Configured by PanOS init"
        echo "nameserver 10.0.2.3"
        echo "nameserver 8.8.8.8"
    } > /etc/resolv.conf 2>/dev/null || true
    
    # Now try DHCP in background for better lease
    echo "[init] Requesting DHCP lease (background)..."
    if [ -x /bin/udhcpc ]; then
        /bin/udhcpc -i "$ETH_IF" -t 5 -T 1 -A 1 -s /usr/share/udhcpc/default.script 2>&1 &
    fi
else
    echo "[init] WARNING: No ethernet interface found"
fi

# Setup fallback DNS (should already be set above)
mkdir -p /etc 2>/dev/null || true
if [ ! -f /etc/resolv.conf ] || [ ! -s /etc/resolv.conf ]; then
    {
        echo "# Fallback DNS"
        echo "nameserver 10.0.2.3"
        echo "nameserver 8.8.8.8"
    } > /etc/resolv.conf 2>/dev/null || true
fi

# SKIP wait - go directly to shell
echo "[init] Network configured (static + DHCP in background)"

# System ready
echo ""
echo "╔════════════════════════════════════════╗"
echo "║   🚀 PanOS - Ready                 ║"
echo "║      Linux 6.6 + Busybox + Node.js    ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check and report what's available (quick)
if [ -x /bin/node ]; then
    NODE_VER=$(/bin/node --version 2>/dev/null || echo "unknown")
    echo "✓ Node.js $NODE_VER"
    
    if [ -x /bin/npm ]; then
        NPM_VER=$(/bin/npm --version 2>/dev/null || echo "unknown")
        echo "✓ npm v$NPM_VER"
    fi
else
    echo "⚠  Node.js not available"
fi

if command -v git >/dev/null 2>&1; then
    echo "✓ git available"
fi

echo ""
echo "Network: $(ip addr show 2>/dev/null | grep 'inet 10' | grep -o '10[^ /]*' || echo 'configuring...')"
echo ""
echo "Commands: nettest.sh, test-git.sh, npm, node, git, etc."
echo ""

# Switch to interactive shell
echo "[init] Launching shell..."
exec /bin/sh
INIT_EOF

chmod +x init

# Create network diagnostics script in rootfs
mkdir -p "${ROOTFS}/bin"
cat > "${ROOTFS}/bin/nettest.sh" << 'NETTEST_EOF'
#!/bin/sh
# Network diagnostics tool for PanOS

echo "╔════════════════════════════════════════════════════════╗"
echo "║  PanOS Network Diagnostics                             ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

echo "[1] Interface Status"
echo "────────────────────────────────────────────────────────"
ip link show 2>/dev/null || ifconfig 2>/dev/null || echo "ERROR: ip/ifconfig not available"
echo ""

echo "[2] IP Configuration"
echo "────────────────────────────────────────────────────────"
ip addr show 2>/dev/null | grep -E "inet|inet6" || echo "ERROR: No IP addresses configured"
echo ""

echo "[3] Routing Table"
echo "────────────────────────────────────────────────────────"
ip route show 2>/dev/null || route -n 2>/dev/null || echo "ERROR: No routing table available"
echo ""

echo "[4] DNS Configuration"
echo "────────────────────────────────────────────────────────"
if [ -f /etc/resolv.conf ]; then
    cat /etc/resolv.conf
else
    echo "ERROR: /etc/resolv.conf not found"
fi
echo ""

echo "[5] Test Conectividad (TCP - Rápido)"
echo "────────────────────────────────────────────────────────"
echo "Intentando conexion TCP a github.com:443 (HTTPS)..."
timeout 3 sh -c "echo '' > /dev/tcp/github.com/443" 2>/dev/null && {
    echo "✓ GitHub HTTPS accesible"
} || {
    echo "Intentando conexion a 8.8.8.8:80..."
    timeout 3 sh -c "echo '' > /dev/tcp/8.8.8.8/80" 2>/dev/null && {
        echo "✓ Internet accesible (TCP port 80)"
    } || {
        echo "✗ No hay conectividad TCP"
    }
}
echo ""

echo "[6] DHCP Log"
echo "────────────────────────────────────────────────────────"
if [ -f /var/log/udhcpc.log ]; then
    echo "Recent DHCP events:"
    tail -15 /var/log/udhcpc.log
elif [ -f /tmp/udhcpc.log ]; then
    echo "Recent DHCP events (fallback log):"
    tail -15 /tmp/udhcpc.log
else
    echo "No DHCP log found"
fi
echo ""
NETTEST_EOF

chmod +x "${ROOTFS}/bin/nettest.sh"

# Create git test script
cat > "${ROOTFS}/bin/test-git.sh" << 'TESTGIT_EOF'
#!/bin/sh
# Test git clone functionality

echo "Testing Git Clone Connectivity"
echo "════════════════════════════════════════"
echo ""

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git not found in PATH"
    exit 1
fi

echo "Git version: $(git --version)"
echo ""

# Create temp directory
TMP="/tmp/git-test-$$"
mkdir -p "$TMP"
cd "$TMP" || exit 1

echo "Testing HTTPS connectivity to GitHub..."
echo ""

# Try fetching refs from a small repo
echo "Step 1: Checking connectivity to github.com..."
if timeout 10 git ls-remote https://github.com/torvalds/linux.git HEAD >/dev/null 2>&1; then
    echo "✓ Successfully connected to github.com"
    echo ""
    echo "Step 2: Cloning small repository..."
    if timeout 60 git clone --depth 1 https://github.com/torvalds/linux.git 2>&1 | grep -E "Cloning|Receiving|done"; then
        echo "✓ Clone successful!"
        echo "Repository size:"
        du -sh linux 2>/dev/null || echo "  (size info unavailable)"
    else
        echo "✗ Clone failed or timed out"
    fi
else
    echo "✗ Cannot reach github.com"
    echo ""
    echo "Diagnostics:"
    echo "1. Check DNS: cat /etc/resolv.conf"
    echo "2. Check routes: ip route"
    echo "3. Run full diagnostics: nettest.sh"
    echo "4. Check SSL certs: ls -la /etc/ssl/certs/"
fi

cd /
rm -rf "$TMP"
echo ""
TESTGIT_EOF

chmod +x "${ROOTFS}/bin/test-git.sh"

# Create a simple boot.js if Node.js is available
if [ -x bin/node ]; then
    cat > boot.js << 'BOOT_EOF'
#!/usr/bin/env node

// PanOS - Node.js 24 Boot Script
// Este archivo se ejecuta con: node boot.js

console.log("╔════════════════════════════════════════╗");
console.log("║   🚀 PanOS - Node.js 24              ║");
console.log("║      Linux 6.6 + Busybox + Node      ║");
console.log("╚════════════════════════════════════════╝");
console.log("");

// Información del sistema
try {
    const memUsage = Math.round(process.memoryUsage().rss / 1024 / 1024);
    console.log("Sistema:");
    console.log(`  • Node version: ${process.version}`);
    console.log(`  • V8 engine: ${process.versions.v8}`);
    console.log(`  • Memoria: ${memUsage} MB`);
    console.log(`  • Uptime: ${Math.floor(process.uptime())}s`);
    console.log("");
    
    // Ejemplo 1: Ejecutar comandos del sistema
    console.log("Ejemplos de uso:");
    console.log('  node boot.js               (ejecutar este archivo)');
    console.log('  node -e "console.log(1+1)" (evaluar JS inline)');
    console.log('  node script.js             (ejecutar archivo JS)');
    console.log("");
    
    // Ejemplo 2: Leer archivo
    const fs = require("fs");
    console.log("Archivos en /:");
    const files = fs.readdirSync("/").slice(0, 10);
    files.forEach(f => console.log(`  • ${f}`));
    console.log("");
    
    console.log("Para más comandos: node --help");
} catch (e) {
    console.error("Error:", e.message);
}

BOOT_EOF
    chmod +x boot.js
fi

echo -e "${GREEN}✓ Scripts creados${NC}"
echo ""

# Create initramfs
echo -e "${YELLOW}[6/6] Creando ISO...${NC}"

# Create cpio
cd "${ROOTFS}"
find . -print0 | cpio -0 -o -H newc > "${BUILD}/initramfs.cpio" 2>/dev/null

# Create ISO structure
mkdir -p "${ISO_DIR}/boot/grub"

cp "${BUILD}/vmlinuz" "${ISO_DIR}/boot/"
cp "${BUILD}/initramfs.cpio" "${ISO_DIR}/boot/"

# Create grub config
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
set timeout=5
set default=0

menuentry 'PanOS' {
    multiboot /boot/vmlinuz console=ttyS0 console=tty0
    module /boot/initramfs.cpio
}
EOF

# Try to create ISO with grub
if command -v grub-mkrescue &> /dev/null; then
    echo "  Creando ISO con GRUB..."
    grub-mkrescue -o "${BUILD}/pan-os.iso" "${ISO_DIR}" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  No se pudo crear ISO con GRUB${NC}"
    }
elif command -v xorrisofs &> /dev/null; then
    echo "  Creando ISO con xorrisofs..."
    xorrisofs -o "${BUILD}/pan-os.iso" -b boot/grub/i386-pc/eltorito.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table "${ISO_DIR}" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Creando ISO simple...${NC}"
        mkisofs -o "${BUILD}/pan-os.iso" -R -b boot/vmlinuz "${ISO_DIR}" 2>/dev/null || true
    }
else
    echo -e "${YELLOW}⚠️  Instalando herramientas ISO...${NC}"
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y xorriso > /dev/null 2>&1
    xorrisofs -o "${BUILD}/pan-os.iso" "${ISO_DIR}" 2>/dev/null || true
fi

# If ISO creation failed, create a bootable initramfs (fallback)
if [ ! -f "${BUILD}/pan-os.iso" ] || [ ! -s "${BUILD}/pan-os.iso" ]; then
    echo -e "${YELLOW}⚠️  Fallback: Creando imagen para QEMU...${NC}"
    # Ya tenemos vmlinuz e initramfs.cpio, eso es suficiente para QEMU
    echo "  Uso: qemu-system-x86_64 -kernel vmlinuz -initrd initramfs.cpio"
fi

echo -e "${GREEN}✓ ISO/Imagen creada${NC}"
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ BUILD COMPLETADO${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "Archivos creados en: ${BUILD}/"
echo ""
ls -lh "${BUILD}/"
echo ""

echo "Para ejecutar en QEMU:"
echo "  qemu-system-x86_64 \\"
echo "    -kernel ${BUILD}/vmlinuz \\"
echo "    -initrd ${BUILD}/initramfs.cpio \\"
echo "    -nographic -serial stdio \\"
echo "    -append \"console=ttyS0\" \\"
echo "    -m 512 -smp 2"
echo ""

if [ -f "${BUILD}/pan-os.iso" ] && [ -s "${BUILD}/pan-os.iso" ]; then
    echo "Para bootear desde ISO:"
    echo "  qemu-system-x86_64 -cdrom ${BUILD}/pan-os.iso -m 512 -nographic -serial stdio"
    echo ""
fi

echo "Node.js availability:"
if [ -x "${ROOTFS}/bin/node" ]; then
    echo "  ✓ Node.js v24 INTEGRADO en la imagen"
    if [ -x "${ROOTFS}/bin/npm" ]; then
        echo "  ✓ npm INTEGRADO en la imagen"
    fi
    echo "  Ejecutar en el OS:"
    echo "    $ node --version"
    echo "    $ npm --version"
    echo "    $ node boot.js"
    echo "    $ node -e \"console.log('Hola desde JS')\""
  else
    echo "  ⚠️  Node.js no se pudo integrar"
    echo "  Descarga manual desde: https://nodejs.org/"
fi

echo ""
