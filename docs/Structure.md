# PanOS - Summary

## Overview

PanOS is a minimal Linux operating system designed to boot with Node.js/npm runtime, packaged as an initramfs for QEMU. This document provides the complete project structure and workflow.

---

## Build Pipeline

**0-install-deps.sh** → Setup build environment (5 min, needs sudo)

**1-build.sh** (Main) → Download and compile Linux 6.6.15 kernel with tinyconfig, create rootfs with Busybox, integrate Node.js v24.0.0, install npm, generate init script with debug output, package initramfs (~140 MB), create bootable ISO with GRUB (20-30 min)

**2-run.sh** → Boot PanOS in QEMU with serial console (3-5 sec to prompt)

**3-check.sh** → Validate kernel, initramfs, Node.js, npm, and ISO artifacts

**4-create-iso.sh** (Optional) → Create bootable GRUB ISO using grub-mkrescue or xorrisofs fallback (5 min)

Output: `~/pan-os-iso/build/` → vmlinuz (~3.3 MB) | initramfs.cpio (~140 MB) | pan-os.iso (~160 MB)

---

## Quick Start

**Hurry?** → Run `./1-build.sh` (20-30 min) → Run `./2-run.sh` → Test Node.js

**Want Details?** → Setup takes 5 min + build takes 20-30 min + configure Node.js + test npm + create ISO optional

**Technical Depth?** → Understand kernel compilation with tinyconfig + initramfs creation with cpio + Node.js as PID 1 + Busybox shell integration + GRUB bootloader setup + QEMU serial console debugging + boot flow optimization

---

## Features

✅ Custom-compiled Linux kernel 6.6.15 | ✅ Node.js v24.0.0 as PID 1 | ✅ npm integrated | ✅ Interactive Busybox shell | ✅ ~160 MB total | ✅ QEMU ready + serial console | ✅ [init] debug output | ✅ Customizable boot.js | ✅ Defensive error handling

---

## System Capabilities

**Commands**: ls, cat, echo, cp, mv, rm, mkdir, touch, find, ps, free, uptime, uname, df, whoami, sed, grep, awk, head, tail, node, npm, vi, wget, ping, kill, jobs, fg, bg

**Tools**: Node.js v24.0.0 runtime | npm package manager | npm init | npm install

---

## Improvements

Enhanced init script with standard `/bin/sh` and [init] debug output | Defensive Node.js download with fallbacks | ISO creation with grub-mkrescue/xorrisofs fallback | All Bun references removed | Performance optimized (no unnecessary delays, kernel tinyconfig)

---

## Timeline

- **First Build**: 20-30 min (includes kernel compilation)
- **Subsequent**: Few minutes (kernel cached)
- **Boot**: ~3-5 sec to prompt
- **Node.js**: ~1 sec first, ~100ms after
- **Kernel**: 5-20 min (depends CPU)

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Hangs at boot | Init issue | Check [init] output |
| Node.js missing | Download failed | Has fallback binary |
| npm unavailable | Copy failed | Run `./3-check.sh` |
| QEMU won't start | Missing binary | Install qemu-system-x86 |
| Kernel fails | Low disk | Need 5 GB free |
| ISO won't boot | grub-mkrescue failed | Tries xorrisofs auto |

---

## Prerequisites

✅ Linux system (Ubuntu/Debian recommended) | ✅ 5 GB free disk space | ✅ 30 minutes available | ✅ Internet connection | ✅ sudo access

---

## Workflow

1. `./0-install-deps.sh` (5 min)
2. `./1-build.sh` (20-30 min) 
3. `./3-check.sh` (verify)
4. `./2-run.sh` (boot)
5. Test commands: `node --version`, `npm --version`, `ls`, `ps aux`

---

## What You Learn

Linux kernel compilation | Initramfs creation with cpio | QEMU emulation | Node.js as init | Busybox utilities | GRUB bootloader | Shell scripting | OS boot sequence

---

**Status**: ✅ Production Ready | **Build Time**: 20-30 min first, few min after | **Size**: ~160 MB | **OS Size in Memory**: ~140 MB | **License**: Educational Use
