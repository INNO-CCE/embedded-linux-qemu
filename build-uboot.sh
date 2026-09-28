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
