#!/bin/bash
# ============================================================
#  从虚拟 SD 卡启动（全自动）
#
#  和 run-qemu.sh 的关键区别：
#    **没有 -device loader**。三个文件全在 SD 卡里，
#    U-Boot 要自己去读——这才是真板子上的流程。
#
#  卡里放了 boot.scr.uimg，U-Boot 的 distro_bootcmd 会自动找到并执行它，
#  所以正常情况下你什么都不用敲，等几秒就进 shell 了。
#
#  唯一剩下的"作弊"是 -kernel u-boot：
#    真板子上 U-Boot 住在 Flash 里，由芯片的 ROM 代码加载。
#    QEMU 给不了我们一块烧好 U-Boot 的 Flash，所以还得让它代劳。
# ============================================================
set -euo pipefail
. "$(dirname "$0")/config.sh"

IMG=$OUT_DIR/sd.img
[ -f "$IMG" ] || die "缺 $IMG（先跑 ./make-sd-image.sh）"

cat <<EOF

─────────────────────────────────────────────────────────────
 这次什么都不用敲。U-Boot 会：
   1. 扫 mmc0（distro_bootcmd）
   2. 在 FAT 根目录找到 boot.scr.uimg
   3. 执行它 —— 里面就是"load 三个文件 + bootz"

 想自己动手的话：在 Hit any key to stop autoboot 时敲个回车，
 停在 => 提示符，然后自己敲这九条：

   setenv fdt_high 0xffffffff
   setenv initrd_high 0xffffffff
   setenv bootargs console=ttyAMA0
   mmc dev 0
   fatls mmc 0:1
   load mmc 0:1 $ADDR_KERNEL zImage
   load mmc 0:1 $ADDR_DTB $DTB_NAME
   load mmc 0:1 $ADDR_INITRD rootfs.cpio.gz.uimg
   bootz $ADDR_KERNEL $ADDR_INITRD $ADDR_DTB

 fatls = 列出卡里的文件（列目录）
 load  = 把文件从卡读进内存地址

 退出 QEMU：Ctrl+A 松手，再按 X
─────────────────────────────────────────────────────────────

EOF

exec qemu-system-arm -M "$QEMU_MACHINE" -m "$QEMU_RAM" -nographic \
  -kernel "$OUT_DIR/u-boot" \
  -drive file="$IMG",if=sd,format=raw
