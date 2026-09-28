#!/bin/bash
# ============================================================
#  编译 BusyBox → 组装最小根文件系统 → 打包
#    输入：$BUSYBOX_SRC
#    产物：out/rootfs.cpio.gz  out/rootfs.cpio.gz.uimg
#
#  这一步做了四件事：编译、安装、补零件、打包。
#  "补零件"指 /dev 设备节点、/etc/inittab、/etc/init.d/rcS、/init 软链接。
# ============================================================
set -euo pipefail
. "$(dirname "$0")/config.sh"

need_dir "$BUSYBOX_SRC"
cd "$BUSYBOX_SRC"

# ---------- 1. 挑配置 ----------
if [ ! -f .config ]; then
    say "挑配置 + 打开静态链接 + 关掉编不过的 tc"
    make CROSS_COMPILE=$CROSS defconfig
    # tc 在较新的内核头文件下编不过，而我们用不到它
    sed -i 's/^CONFIG_TC=y$/# CONFIG_TC is not set/' .config
    # 静态链接：根文件系统里就不用再装 libc
    sed -i 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' .config
    make CROSS_COMPILE=$CROSS olddefconfig
    grep -q '^CONFIG_STATIC=y' .config || die "CONFIG_STATIC 没打开，检查 .config"
else
    say "已有 .config，跳过挑配置"
fi

# ---------- 2. 编译 ----------
say "编译 BusyBox"
make CROSS_COMPILE=$CROSS -j$JOBS

# ---------- 3. 安装进 rootfs 目录 ----------
say "安装到 $ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"
make CROSS_COMPILE=$CROSS CONFIG_PREFIX="$ROOTFS_DIR" install

# ---------- 4. 补齐最小零件 ----------
say "补齐 /dev、/etc/inittab、/etc/init.d/rcS"
cd "$ROOTFS_DIR"
mkdir -p dev etc/init.d proc sys tmp

# 设备节点。这两行必须用管理员权限。
if [ ! -c dev/console ] || [ ! -c dev/null ]; then
    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi
    $SUDO mknod -m 622 dev/console c 5 1
    $SUDO mknod -m 666 dev/null    c 1 3
fi

# init 在什么时机干什么
printf '%s\n' \
  '::sysinit:/etc/init.d/rcS' \
  '::askfirst:/bin/sh' \
  '::ctrlaltdel:/sbin/reboot' \
  '::shutdown:/bin/umount -a -r' > etc/inittab

# 系统起来后第一件要做的事
printf '%s\n' \
  '#!/bin/sh' \
  'mount -t proc none /proc' \
  'mount -t sysfs none /sys' \
  'echo "欢迎进入嵌入式 Linux"' > etc/init.d/rcS
chmod +x etc/init.d/rcS

# 内核在 initramfs 里找的入口固定叫 /init（不是 /sbin/init）
ln -sf sbin/init init

# ---------- 5. 打包成 initramfs ----------
say "打包成 initramfs"
mkdir -p "$OUT_DIR"
find . | cpio -o -H newc 2>/dev/null | gzip -9 > "$OUT_DIR/rootfs.cpio.gz"

# ---------- 6. 包成 uImage ----------
# 加了 64 字节的头之后，U-Boot 自己就知道 initrd 有多大，
# 启动时 bootz 就不用再手输大小了。
MKIMAGE=$UBOOT_SRC/tools/mkimage
if [ -x "$MKIMAGE" ]; then
    "$MKIMAGE" -A arm -O linux -T ramdisk -C none \
        -n rootfs -d "$OUT_DIR/rootfs.cpio.gz" "$OUT_DIR/rootfs.cpio.gz.uimg" >/dev/null
    say "产物"
    ls -lh "$OUT_DIR"/rootfs.cpio.gz*
else
    say "没找到 mkimage，只产出 rootfs.cpio.gz"
    echo "  先跑 ./build-uboot.sh，再重跑本脚本就能得到 .uimg"
    ls -lh "$OUT_DIR/rootfs.cpio.gz"
fi
