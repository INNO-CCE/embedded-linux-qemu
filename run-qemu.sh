#!/bin/bash
# ============================================================
#  在 QEMU 里启动整套系统
#
#  它做两件事：
#    1. 用 -device loader 把内核 / 设备树 / initrd 预放进内存的固定地址
#    2. 启动 U-Boot，让你在 => 提示符下敲 bootz
# ============================================================
set -euo pipefail
. "$(dirname "$0")/config.sh"

for f in u-boot zImage "$DTB_NAME" rootfs.cpio.gz.uimg; do
    [ -f "$OUT_DIR/$f" ] || die "缺 $OUT_DIR/$f
  依次跑：./build-kernel.sh  ./build-uboot.sh  ./build-busybox.sh"
done

cat <<EOF

─────────────────────────────────────────────────────────────
 QEMU 起来之后，等 U-Boot 打出 => 提示符，依次敲这四条：

   setenv fdt_high 0xffffffff
   setenv initrd_high 0xffffffff
   setenv bootargs console=ttyAMA0
   bootz $ADDR_KERNEL $ADDR_INITRD $ADDR_DTB

 （中间如果出现 Hit any key to stop autoboot，敲一下回车）
 退出 QEMU：Ctrl+A 松手，再按 X
─────────────────────────────────────────────────────────────

EOF

exec qemu-system-arm -M "$QEMU_MACHINE" -m "$QEMU_RAM" -nographic \
  -kernel "$OUT_DIR/u-boot" \
  -device loader,file="$OUT_DIR/zImage",addr=$ADDR_KERNEL \
  -device loader,file="$OUT_DIR/$DTB_NAME",addr=$ADDR_DTB \
  -device loader,file="$OUT_DIR/rootfs.cpio.gz.uimg",addr=$ADDR_INITRD
