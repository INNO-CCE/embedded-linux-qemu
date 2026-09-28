#!/bin/bash
# ============================================================
#  下载三个源码包。**只有换新机器时才需要跑这个。**
#  已经解压过的会被跳过。
# ============================================================
set -euo pipefail
. "$(dirname "$0")/config.sh"

TUNA=https://mirrors.tuna.tsinghua.edu.cn

# ---------- Linux 内核 ----------
mkdir -p "$(dirname "$KERNEL_SRC")"
cd "$(dirname "$KERNEL_SRC")"
TAR=linux-$KERNEL_VER.tar.xz
if [ ! -f "$KERNEL_SRC/Makefile" ]; then
    say "下载内核源码 $TAR（约 140 MB）"
    [ -f "$TAR" ] || wget -c "$TUNA/kernel/v6.x/$TAR"
    say "解压 $TAR"
    tar -xf "$TAR"
fi

# ---------- BusyBox ----------
mkdir -p "$(dirname "$BUSYBOX_SRC")"
cd "$(dirname "$BUSYBOX_SRC")"
TAR=busybox-$BUSYBOX_VER.tar.bz2
if [ ! -f "$BUSYBOX_SRC/Makefile" ]; then
    say "下载 BusyBox $TAR（约 2.5 MB）"
    [ -f "$TAR" ] || wget -c "https://busybox.net/downloads/$TAR"
    say "解压 $TAR"
    tar -xf "$TAR"
fi

# ---------- U-Boot ----------
mkdir -p "$(dirname "$UBOOT_SRC")"
cd "$(dirname "$UBOOT_SRC")"
TAR=u-boot-$UBOOT_VER.tar.bz2
if [ ! -f "$UBOOT_SRC/Makefile" ]; then
    say "下载 U-Boot $TAR（约 30 MB，denx.de 在国内可能慢）"
    [ -f "$TAR" ] || wget -c "https://ftp.denx.de/pub/u-boot/$TAR"
    say "解压 $TAR"
    tar -xf "$TAR"
fi

say "源码就位"
echo "  内核   $KERNEL_SRC"
echo "  BusyBox $BUSYBOX_SRC"
echo "  U-Boot $UBOOT_SRC"
