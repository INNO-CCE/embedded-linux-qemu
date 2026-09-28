#!/bin/bash
# ============================================================
#  一次把三个都编出来（顺序有讲究，见下）
#
#  顺序原因：build-busybox.sh 的最后一步要用 U-Boot 编出来的
#  tools/mkimage 来打包 initrd，所以 U-Boot 要在 BusyBox 之前编。
# ============================================================
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

"$HERE/build-kernel.sh"
"$HERE/build-uboot.sh"
"$HERE/build-busybox.sh"

printf '\n\033[1;32m全部完成。接下来跑 ./run-qemu.sh\033[0m\n'
