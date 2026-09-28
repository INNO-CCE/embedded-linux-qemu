#!/bin/bash
# ============================================================
#  编译 Linux 内核
#    输入：$KERNEL_SRC
#    产物：out/zImage  out/vexpress-v2p-ca9.dtb
# ============================================================
set -euo pipefail
. "$(dirname "$0")/config.sh"

need_dir "$KERNEL_SRC"
cd "$KERNEL_SRC"

# ---------- 1. 挑配置 ----------
if [ ! -f .config ]; then
    say "挑配置：$KERNEL_DEFCONFIG"
    make ARCH=arm CROSS_COMPILE=$CROSS $KERNEL_DEFCONFIG
else
    say "已有 .config，跳过挑配置（想从默认配置重来：先 rm .config）"
fi

# ---------- 2. 编译 ----------
say "编译内核（第一次大约 6 分钟）"
make ARCH=arm CROSS_COMPILE=$CROSS -j$JOBS zImage dtbs

[ -f arch/arm/boot/zImage ] || die "没编出 zImage，看上面的报错"

# 设备树在新版内核里挪进了子目录，所以用 find 拿真实路径
DTB_PATH=$(find arch/arm/boot/dts -name "$DTB_NAME" -print -quit)
[ -n "$DTB_PATH" ] || die "没找到 $DTB_NAME"

# ---------- 3. 收产物 ----------
mkdir -p "$OUT_DIR"
cp arch/arm/boot/zImage "$OUT_DIR/"
cp "$DTB_PATH" "$OUT_DIR/"

say "产物"
ls -lh "$OUT_DIR/zImage" "$OUT_DIR/$DTB_NAME"
