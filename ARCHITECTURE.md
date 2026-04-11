# PanOS Architecture

## Overview

PanOS is a minimal Linux distribution built from scratch. It compiles a custom kernel, bundles Busybox for POSIX utilities, and includes Node.js v24 as an integrated JavaScript runtime. The entire system boots from a single initramfs image.

```
+-------------------------------------------------------------------+
|                        Host Machine                               |
|                                                                   |
|  panos.sh (menu)                                                  |
|      |                                                            |
|      +-- scripts/build/install-deps.sh   (apt-get packages)      |
|      +-- scripts/build/build-system.sh   (kernel + rootfs)        |
|      +-- scripts/iso/create-iso.sh       (GRUB ISO)              |
|      +-- scripts/run/run-qemu.sh         (QEMU launcher)         |
|      +-- scripts/build/build-arm64.sh    (cross-compile)          |
|                                                                   |
|  Build Output: ~/pan-os-iso/build/                                |
|      vmlinuz          (custom kernel ~3.3 MB)                     |
|      initramfs.cpio   (root filesystem ~142 MB)                   |
|      pan-os*.iso      (bootable ISO ~156 MB)                      |
+-------------------------------------------------------------------+
```

## Build Pipeline

The build pipeline runs in 6 stages:

```
[1] Prepare workspace
     |
     v
[2] Download & compile Linux kernel 6.6.15
     |  - Download source from kernel.org
     |  - Apply minimal .config (serial, ELF, initrd, networking, VirtIO)
     |  - Compile with make -j$(nproc)
     |  - Output: vmlinuz
     v
[3] Create root filesystem (rootfs)
     |  - Create directory structure (/bin, /dev, /etc, /lib, /proc, etc.)
     |  - Download Busybox static binary
     |  - Install Busybox symlinks (ls, sh, mount, ip, etc.)
     |  - Copy glibc shared libraries from host
     |  - Integrate Git (optional, with SSL certs)
     v
[4] Download Node.js v24
     |  - Download official binary (x64 or arm64)
     |  - Install node, npm, npx
     |  - Copy npm modules to /lib/node_modules
     v
[5] Create init script & utilities
     |  - /init: PID 1 process (mounts, networking, launches shell)
     |  - /boot.js: Node.js demo script
     |  - /bin/nettest.sh: Network diagnostics
     v
[6] Package initramfs
     |  - find . | cpio -H newc > initramfs.cpio
     v
   [Done] vmlinuz + initramfs.cpio ready
```

## Boot Sequence

```
BIOS/UEFI
  |
  +-- GRUB (if booting from ISO)
  |     |
  |     +-- loads /boot/vmlinuz
  |     +-- loads /boot/initramfs.cpio
  |
  +-- QEMU direct boot (if using -kernel/-initrd)
        |
        v
Linux Kernel (vmlinuz)
  |
  +-- Unpacks initramfs.cpio into memory
  +-- Executes /init as PID 1
        |
        v
/init script (busybox sh)
  |
  +-- mount /proc, /sys, /dev, /tmp
  +-- Create device nodes (/dev/console, /dev/tty, etc.)
  +-- Configure networking:
  |     +-- Bring up loopback (lo)
  |     +-- Detect ethernet interface (eth0/enp0s3/ens3)
  |     +-- Set static IP (10.0.2.15/24 for QEMU user networking)
  |     +-- Set default gateway (10.0.2.2)
  |     +-- Configure DNS (10.0.2.3, 8.8.8.8)
  |     +-- Start DHCP client in background (udhcpc)
  +-- Print system info (Node.js version, npm, git)
  +-- exec /bin/sh (interactive shell)
```

## Rootfs Layout

```
/ (initramfs root)
  /init                    # PID 1 init script
  /boot.js                 # Node.js demo script
  /bin/
    busybox                # Static Busybox binary (1.35)
    sh -> busybox          # Shell (symlink)
    ls -> busybox          # (and ~300 more symlinks)
    node                   # Node.js v24 binary
    npm                    # npm wrapper script
    npx                    # npx wrapper script
    nettest.sh             # Network diagnostics
  /lib/
    libc.so.6              # glibc C library
    libm.so.6              # Math library
    libstdc++.so.6         # C++ standard library
    libgcc_s.so.1          # GCC runtime
    node_modules/
      npm/                 # npm package manager
  /lib64/
    ld-linux-x86-64.so.2   # Dynamic linker
  /dev/                    # Device files (devtmpfs)
  /proc/                   # Process filesystem
  /sys/                    # Sysfs
  /etc/
    resolv.conf            # DNS configuration
    ssl/certs/             # SSL certificates (for git/https)
  /usr/
    bin/env -> /bin/env    # For #!/usr/bin/env scripts
    lib/git-core/          # Git core executables
    share/udhcpc/          # DHCP client scripts
  /tmp/                    # Temporary files (tmpfs)
  /root/                   # Root home directory
```

## Networking

QEMU user-mode networking provides:

```
Guest (PanOS)                    Host
  10.0.2.15/24                    localhost
       |                             |
       +--- eth0 ---[QEMU NAT]------+
       |                             |
  Gateway: 10.0.2.2          Port forwards:
  DNS:     10.0.2.3            2222 -> guest:22
                               8080 -> guest:80
                               5173 -> guest:5173
```

The init script configures networking in two phases:
1. **Static IP** (immediate): Sets 10.0.2.15/24 for instant connectivity
2. **DHCP** (background): Runs udhcpc for proper lease

## Architecture Support

| Architecture | Kernel   | Busybox  | Node.js  | QEMU Machine |
|-------------|----------|----------|----------|--------------|
| x86_64      | bzImage  | musl x64 | linux-x64 | default (pc) |
| aarch64     | Image    | musl arm64 | linux-arm64 | virt        |

### x86_64 (default)

Standard build. Uses `qemu-system-x86_64` with serial console.

### aarch64 (ARM64)

Cross-compiled build for ARM64. Uses:
- `aarch64-linux-gnu-gcc` cross-compiler
- `qemu-system-aarch64 -machine virt` for emulation
- ARM64-specific kernel config (PL011 UART, VirtIO MMIO)

Suitable for: Raspberry Pi 3/4/5, ARM servers, phones with custom bootloaders.

## Docker Architecture

```
+--------------------------------------------------+
|  Docker Multi-Stage Build                        |
|                                                  |
|  Stage 1: Builder (ubuntu:22.04)                 |
|    - Install build-essential, gcc, etc.          |
|    - Run scripts/build/build-system.sh           |
|    - Output: vmlinuz + initramfs.cpio            |
|                                                  |
|  Stage 2: Runtime (ubuntu:22.04)                 |
|    - Install qemu-system-x86 only               |
|    - Copy artifacts from Stage 1                 |
|    - Entrypoint: docker/entrypoint.sh            |
|      -> launches qemu-system-x86_64             |
|      -> with KVM acceleration if /dev/kvm exists |
+--------------------------------------------------+
```

Environment variables for the Docker runtime:

| Variable | Default | Description |
|----------|---------|-------------|
| `PANOS_MEM_MB` | 2048 | RAM in MB |
| `PANOS_SMP` | 2 | CPU cores |
| `PANOS_BOOT` | initrd | Boot mode: `initrd` or `iso` |
| `PANOS_NET` | user | Network: `user` or `none` |
| `PANOS_QEMU_ARGS` | (empty) | Extra QEMU arguments |

## Kernel Configuration

The kernel is configured with `allnoconfig` as a base, then only essential options are enabled:

| Category | Key Options | Purpose |
|----------|-------------|---------|
| Serial console | SERIAL_8250, SERIAL_8250_CONSOLE | QEMU serial output |
| Filesystems | PROC_FS, SYSFS, DEVTMPFS, EXT4_FS | Required for Linux |
| Boot | BLK_DEV_INITRD, RD_GZIP, BINFMT_ELF | initramfs + ELF binaries |
| Storage | SCSI, SATA_AHCI, ATA, VIRTIO_BLK | Disk access |
| Networking | NET, INET, VIRTIO_NET, E1000 | TCP/IP stack |
| Input | INPUT_KEYBOARD, MOUSE_PS2 | User input |
| Crypto | CRYPTO_AES, CRYPTO_SHA256 | HTTPS support |

## Build Times

Approximate times on a modern machine (4+ cores):

| Step | Duration |
|------|----------|
| Download kernel source | 1-3 min |
| Compile kernel | 5-15 min |
| Download Busybox + Node.js | 1-2 min |
| Create rootfs + initramfs | < 1 min |
| Create ISO | < 1 min |
| **Total** | **~10-20 min** |

## Security Notes

- PanOS is an **educational/development** OS, not hardened for production
- The root filesystem runs entirely in RAM (no disk persistence)
- No user authentication (boots directly to root shell)
- Network is NATed through QEMU (not directly exposed)
- SSL certificates are copied from host for git/https functionality
