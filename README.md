# PanOS

A minimal Linux operating system with Node.js built in, bootable in QEMU and from ISO.

## What Is This?

PanOS is a from-scratch Linux distribution that compiles a custom kernel, bundles Busybox for core Unix tools, and ships Node.js v24 with npm as an integrated JavaScript runtime — all packed into a single bootable initramfs image (~145 MB).

| Component    | Details                         |
|--------------|---------------------------------|
| **Kernel**   | Linux 6.6.15 (custom minimal)  |
| **Shell**    | Busybox 1.35 (static)          |
| **JS Runtime** | Node.js v24.0.0 + npm        |
| **Boot**     | initramfs (cpio), GRUB ISO     |
| **VM**       | QEMU x86_64 (serial console)   |

## Prerequisites

A Debian/Ubuntu-based host with the following packages:

```
build-essential  bc  bison  flex  libelf-dev  libssl-dev
wget  xz-utils  cpio  grub-common  xorriso  qemu-system-x86
```

Install them all at once:

```bash
sudo apt-get update && sudo apt-get install -y \
  build-essential bc bison flex libelf-dev libssl-dev \
  wget xz-utils cpio grub-common xorriso qemu-system-x86
```

Or just run:

```bash
./0-install-deps.sh
```

## Quick Start

```bash
./0-install-deps.sh   # install host packages (needs sudo)
./1-build.sh          # download, compile, and package everything (~20-30 min)
./2-run.sh            # boot PanOS in QEMU (serial console)
```

Once booted you will see a `/ #` shell prompt. Try:

```bash
node --version                    # v24.0.0
npm --version                     # 10.x.x
node -e "console.log(1 + 1)"     # 2
node boot.js                     # system info demo
npm init -y                       # create package.json
ls /bin | head                    # busybox symlinks
ps aux                            # running processes
free -h                           # memory usage
```

To exit QEMU: press **Ctrl+A** then **X**.

## Project Files

| File               | Purpose |
|--------------------|---------|
| `0-install-deps.sh` | Installs required host packages via `apt-get` |
| `1-build.sh`        | Downloads kernel 6.6.15, compiles it, creates rootfs with Busybox + Node.js + npm, produces `vmlinuz` and `initramfs.cpio` |
| `2-run.sh`          | Launches QEMU with the built kernel and initramfs (serial console) |
| `3-check.sh`        | Validates build artifacts (kernel, initramfs, Node.js, npm presence, ISO) |
| `4-create-iso.sh`   | Creates a GRUB-based bootable ISO (`pan-os-booteable.iso`) |
| `2-run.sh`          | Launches QEMU with the built kernel and initramfs (serial console) |
| `3-check.sh`        | Validates build artifacts (kernel, initramfs, Node.js presence, ISO) |
| `4-create-iso.sh`   | Creates a GRUB-based bootable ISO (`pan-os-booteable.iso`) |

## Gallery

![img](/grub.png)
![img](/qemu.png)
![img](/vm-vite.png)
![img](/qemu-vite.png)

## Build Artifacts

All output goes to `~/pan-os-iso/build/`:

```
~/pan-os-iso/build/
├── vmlinuz               # Custom Linux kernel (~3.3 MB)
├── initramfs.cpio        # Root filesystem image (~142 MB)
└── pan-os-booteable.iso  # Bootable ISO with GRUB (~156 MB)
```

## Creating a Bootable ISO

After building:

```bash
./4-create-iso.sh
```

This uses `grub-mkrescue` to produce `pan-os-booteable.iso`. You can then:

```bash
# QEMU (from ISO)
qemu-system-x86_64 -cdrom ~/pan-os-iso/build/pan-os-booteable.iso -m 1024

# VirtualBox / VMware
#   Attach the ISO as a virtual DVD drive

# USB stick (replace /dev/sdX with your device!)
sudo dd if=~/pan-os-iso/build/pan-os-booteable.iso of=/dev/sdX bs=4M status=progress
```

## How It Works (Build from Scratch Guide)

If you need to replicate this without the scripts, here is what happens end to end:

### 1. Compile a Minimal Linux Kernel

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.15.tar.xz
tar xf linux-6.6.15.tar.xz && cd linux-6.6.15
make allnoconfig
```

Apply a minimal `.config` enabling:

```
CONFIG_64BIT=y
CONFIG_X86_64=y
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
CONFIG_INPUT=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_ATA=y
CONFIG_ATA_SFF=y
CONFIG_SATA_AHCI=y
CONFIG_SCSI=y
```

Then:

```bash
make oldconfig < /dev/null
make -j$(nproc)
cp arch/x86/boot/bzImage ../vmlinuz
```

### 2. Build a Root Filesystem

```bash
mkdir -p rootfs/{bin,dev,etc,lib,lib64,proc,sbin,sys,tmp,root,usr/bin,usr/lib}
cd rootfs/bin

# Get Busybox
wget https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
chmod +x busybox
./busybox --install .
cd ..
```

### 3. Add Node.js

```bash
cd rootfs/bin
wget https://nodejs.org/dist/v24.0.0/node-v24.0.0-linux-x64.tar.xz -O node.tar.xz
tar xf node.tar.xz
mv node-v24.0.0-linux-x64/bin/node .
mv node-v24.0.0-linux-x64/bin/npm .
mv node-v24.0.0-linux-x64/bin/npx .
chmod +x node npm npx

# Copy Node.js libraries including npm modules
cd ..
mkdir -p lib
cp -r bin/node-v24.0.0-linux-x64/lib/* lib/

cd bin
rm -rf node-v24.0.0-linux-x64 node.tar.xz
```

Node.js is dynamically linked, so copy required glibc libraries from the host:

```bash
# From rootfs/
cp /lib/x86_64-linux-gnu/libc.so.6 lib/
cp /lib/x86_64-linux-gnu/libm.so.6 lib/
cp /lib/x86_64-linux-gnu/libdl.so.2 lib/
cp /lib/x86_64-linux-gnu/libpthread.so.0 lib/
cp /lib/x86_64-linux-gnu/libstdc++.so.6 lib/
cp /lib/x86_64-linux-gnu/libgcc_s.so.1 lib/
cp /lib64/ld-linux-x86-64.so.2 lib64/
```

### 4. Create the Init Script

Create `rootfs/init`:

```bash
#!/bin/busybox sh
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys
busybox mount -t devtmpfs devtmpfs /dev
busybox mount -t tmpfs tmpfs /tmp

echo "PanOS ready"
exec /bin/busybox sh
```

```bash
chmod +x rootfs/init
```

### 5. Package the Initramfs

```bash
cd rootfs
find . -print0 | cpio -0 -o -H newc > ../initramfs.cpio
```

### 6. Boot with QEMU

```bash
qemu-system-x86_64 \
  -kernel vmlinuz \
  -initrd initramfs.cpio \
  -nographic -serial stdio -monitor none \
  -append "console=ttyS0" \
  -m 1024 -smp 2
```

### 7. Create a Bootable ISO (Optional)

```bash
mkdir -p iso/boot/grub
cp vmlinuz initramfs.cpio iso/boot/

cat > iso/boot/grub/grub.cfg << 'EOF'
set default=0
set timeout=10
menuentry "PanOS" {
    linux /boot/vmlinuz console=ttyS0 console=tty0
    initrd /boot/initramfs.cpio
}
EOF

grub-mkrescue --output=panos.iso --label=PANOS iso/
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Blank screen in QEMU | Make sure you pass `-nographic -serial stdio -append "console=ttyS0"` |
| `node: not found` | Verify `bin/node` exists and is executable inside the initramfs |
| `npm: not found` | Verify `bin/npm` exists and `lib/node_modules` directory is present |
| `node: error while loading shared libraries` | Copy the required glibc `.so` files into `rootfs/lib/` and `rootfs/lib64/` |
| Kernel panic: no init found | Ensure `rootfs/init` exists and is `chmod +x` |
| ISO not bootable | Use `grub-mkrescue` (requires `grub-common` and `xorriso`) |

## Architecture

```
Host (Linux x86_64)
 │
 ├─ 1-build.sh ──────────────────────────────────────────────┐
 │   ├─ Downloads kernel 6.6.15 source                      │
 │   ├─ Applies minimal .config (serial, ELF, initrd, etc.) │
 │   ├─ Compiles with make -j$(nproc) → vmlinuz             │
 │   ├─ Downloads Busybox static binary → /bin/*             │
 │   ├─ Downloads Node.js v24 → /bin/node, /bin/npm, /bin/npx │
 │   ├─ Copies Node.js libs + npm modules → /lib/           │
 │   ├─ Copies glibc shared libs → /lib/, /lib64/           │
 │   ├─ Generates /init (busybox sh as PID 1)               │
 │   └─ Packs rootfs → initramfs.cpio                       │
 │                                                            │
 ├─ 2-run.sh ────────────────────────────────────────────────┤
 │   └─ qemu-system-x86_64 -kernel vmlinuz                  │
 │        -initrd initramfs.cpio -nographic -serial stdio    │
 │                                                            │
 └─ 4-create-iso.sh ────────────────────────────────────────┘
     └─ grub-mkrescue → pan-os-booteable.iso
```

## License

Educational project. Kernel source is GPL-licensed. Busybox is GPL-licensed. Node.js is MIT-licensed.
