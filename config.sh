#!/bin/bash
# ============================================================
#  集中配置：所有路径、版本号、加载地址都在这儿。
#  换机器 / 换版本时，只需要改这一个文件。
# ============================================================

# ---- 版本 ----
KERNEL_VER=6.12
BUSYBOX_VER=1.36.1
UBOOT_VER=2024.10

# ---- 交叉工具链前缀（结尾那个连字符不能少）----
CROSS=arm-linux-gnueabihf-

# ---- 并行任务数（= 虚拟机 CPU 核数）----
JOBS=4

# ---- 目标板 ----
QEMU_MACHINE=vexpress-a9
# 板级配置（vexpress）假定内存有 1 GB，所以这里也给它 1 GB。
# 注意 U-Boot 会打印 "DRAM: 512 MiB (effective 1 GiB)"——那是它的探测
# 和配置对不上，属于这块板子的老毛病，无害。
QEMU_RAM=1024M
KERNEL_DEFCONFIG=vexpress_defconfig
UBOOT_DEFCONFIG=vexpress_ca9x4_defconfig
DTB_NAME=vexpress-v2p-ca9.dtb

# ---- 源码目录（已下载好的地方；换机器就改这里，或跑 fetch-sources.sh）----
KERNEL_SRC=${KERNEL_SRC:-$HOME/kernel/linux-$KERNEL_VER}
BUSYBOX_SRC=${BUSYBOX_SRC:-$HOME/busybox/busybox-$BUSYBOX_VER}
UBOOT_SRC=${UBOOT_SRC:-$HOME/uboot/u-boot-$UBOOT_VER}

# ---- 根文件系统的组装目录 ----
ROOTFS_DIR=${ROOTFS_DIR:-$HOME/rootfs}

# ---- 产物目录：本脚本所在的目录下的 out/ ----
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT_DIR=$HERE/out

# ---- QEMU 把三个文件预放进内存的地址 ----
ADDR_DTB=0x61000000
ADDR_KERNEL=0x62000000
ADDR_INITRD=0x64000000

# ---- 小工具 ----
say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m错误：%s\033[0m\n' "$*" >&2; exit 1; }
need_dir() { [ -d "$1" ] || die "目录不存在：$1（先跑 ./fetch-sources.sh）"; }
