#!/bin/bash
# ============================================================
#  编译 U-Boot
#    输入：$UBOOT_SRC
#    产物：out/u-boot（ELF，给 QEMU）  out/u-boot.bin（纯二进制，给真机 Flash）
# ============================================================
set -euo pipefail
. "$(dirname "$0")/config.sh"

need_dir "$UBOOT_SRC"
cd "$UBOOT_SRC"

# ---------- 0. 改写默认 bootcmd ----------
# 为什么要改：这片板子的 U-Boot 默认 bootcmd 是
#     run distro_bootcmd; run bootflash
# 但它的默认环境里**缺一堆关键变量**（scriptaddr、pxefile_addr_r、
# ramdisk_addr …），而且 `load` 这条命令根本不可用。
# 结果两条自动启动路径都是坏的，开机只能掉到 => 提示符。
#
# 所以这里直接换成我们自己的命令：用亲测可用的 `fatload` 从 SD 卡
# 把三个文件读进内存，再 bootz。
BOOTCMD="setenv fdt_high 0xffffffff; setenv initrd_high 0xffffffff; \
setenv bootargs console=ttyAMA0; \
fatload mmc 0:1 $ADDR_KERNEL zImage; \
fatload mmc 0:1 $ADDR_DTB $DTB_NAME; \
fatload mmc 0:1 $ADDR_INITRD rootfs.cpio.gz.uimg; \
bootz $ADDR_KERNEL $ADDR_INITRD $ADDR_DTB"

say "改写 U-Boot 的默认 bootcmd"
sed -i '/^CONFIG_BOOTCOMMAND=/d' "configs/$UBOOT_DEFCONFIG"
printf 'CONFIG_BOOTCOMMAND="%s"\n' "$BOOTCMD" >> "configs/$UBOOT_DEFCONFIG"

# 必须删掉旧的 .config，否则下面的「挑配置」会被跳过，改动不生效
rm -f .config

# ---------- 1. 挑配置 ----------
if [ ! -f .config ]; then
    say "挑配置：$UBOOT_DEFCONFIG"
    make ARCH=arm CROSS_COMPILE=$CROSS $UBOOT_DEFCONFIG
else
    say "已有 .config，跳过挑配置"
fi

# ---------- 2. 编译 ----------
say "编译 U-Boot"
make ARCH=arm CROSS_COMPILE=$CROSS -j$JOBS

[ -f u-boot ] || die "没编出 u-boot，看上面的报错"

# ---------- 3. 收产物 ----------
mkdir -p "$OUT_DIR"
cp u-boot "$OUT_DIR/"
if [ -f u-boot.bin ]; then cp u-boot.bin "$OUT_DIR/"; fi

say "产物"
ls -lh "$OUT_DIR"/u-boot*

echo
echo "提示：U-Boot 编出来的 tools/mkimage 会被 build-busybox.sh 用来打包 initrd。"
