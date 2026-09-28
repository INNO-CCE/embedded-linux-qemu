#!/bin/bash
# ============================================================
#  造一张可以当"SD 卡"用的虚拟磁盘镜像
#
#  做五件事（真机上你用读卡器做的是同一套流程）：
#    1. 造一个空的镜像文件               ← 相当于"拿到一张空卡"
#    2. 写 MBR 分区表 + 一个 FAT 分区     ← 相当于"分区、格式化"
#        并且标记成"可启动"（bootable）
#    3. 挂成回环设备（loop device）
#    4. 生成 U-Boot 启动脚本 boot.scr     ← 让 U-Boot 开机自动找到它
#    5. 把内核 / 设备树 / initrd / boot.scr 拷进去
#
#  产物：out/sd.img
# ============================================================
set -euo pipefail
. "$(dirname "$0")/config.sh"

IMG=$OUT_DIR/sd.img
SIZE_MB=${SD_SIZE_MB:-64}
MNT=$(mktemp -d)
LOOP=""

cleanup() {
    if [ -n "$LOOP" ]; then sudo losetup -d "$LOOP" 2>/dev/null || true; fi
    rmdir "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

for f in zImage "$DTB_NAME" rootfs.cpio.gz.uimg; do
    [ -f "$OUT_DIR/$f" ] || die "缺 $OUT_DIR/$f（先跑 ./build-all.sh）"
done

say "1/5 造 ${SIZE_MB} MB 空镜像"
rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1M count="$SIZE_MB" status=none

say "2/5 写分区表：从 1 MB 处开始，一个 FAT 分区，标记为可启动"
sfdisk "$IMG" >/dev/null <<'EOF'
label: dos
start=2048, type=c, bootable
EOF

say "3/5 挂成回环设备并格式化成 FAT（需要管理员权限）"
LOOP=$(sudo losetup -f --show -P "$IMG")
sleep 1     # 给内核一点时间识别分区
sudo mkfs.vfat -n BOOT "${LOOP}p1" >/dev/null

# U-Boot 的 distro_bootcmd 会去 FAT 根目录找 boot.scr.uimg / boot.scr，
# 找到就自动执行它。所以把要敲的那几条命令写成一个文本文件，
# 再用 mkimage 包成 U-Boot 能读的脚本镜像。
say "4/5 生成 boot.scr（U-Boot 开机自动执行的脚本）"
cat > "$OUT_DIR/boot.cmd" <<EOF
setenv fdt_high 0xffffffff
setenv initrd_high 0xffffffff
setenv bootargs console=ttyAMA0
load mmc 0:1 $ADDR_KERNEL zImage
load mmc 0:1 $ADDR_DTB $DTB_NAME
load mmc 0:1 $ADDR_INITRD rootfs.cpio.gz.uimg
bootz $ADDR_KERNEL $ADDR_INITRD $ADDR_DTB
EOF
"$UBOOT_SRC/tools/mkimage" -A arm -O linux -T script -C none \
    -n boot -d "$OUT_DIR/boot.cmd" "$OUT_DIR/boot.scr.uimg" >/dev/null

say "5/5 把文件拷进 FAT 分区"
sudo mount "${LOOP}p1" "$MNT"
sudo cp "$OUT_DIR/zImage" "$OUT_DIR/$DTB_NAME" \
        "$OUT_DIR/rootfs.cpio.gz.uimg" "$OUT_DIR/boot.scr.uimg" "$MNT/"
sync
sudo umount "$MNT"

say "SD 镜像好了"
ls -lh "$IMG"
echo
echo "  卡里现在有：zImage  $DTB_NAME  rootfs.cpio.gz.uimg  boot.scr.uimg"
echo "  下一步：./run-qemu-sd.sh  —— U-Boot 会自己找到 boot.scr 并启动"
