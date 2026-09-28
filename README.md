# embedded-linux-qemu

从源码构建一套完整的嵌入式 Linux 系统，并在 QEMU 里启动它。

**不用买开发板。** 交叉编译、内核、根文件系统、bootloader——
每个环节都是自己编出来的，不是下载现成的发行版镜像。

---

## 一键跑

```bash
./build-all.sh     # 编内核 → 编 U-Boot → 编 BusyBox 并打包根文件系统
./run-qemu.sh      # 启动 QEMU，按屏幕提示在 U-Boot 里敲四条命令
```

**换新机器时**，先拉源码（已经下过的会跳过）：

```bash
./fetch-sources.sh
```

第一次完整构建大约 10 分钟（内核 6 分钟 + U-Boot 1 分钟 + BusyBox 2 分钟）。

---

## 脚本

| 脚本 | 干什么 | 产物 |
|---|---|---|
| `config.sh` | **所有路径、版本号、加载地址** | —— |
| `fetch-sources.sh` | 下载三个源码包（只有新机器需要） | `~/kernel`、`~/busybox`、`~/uboot` |
| `build-kernel.sh` | 编内核 | `out/zImage`、`out/vexpress-v2p-ca9.dtb` |
| `build-uboot.sh` | 编 U-Boot | `out/u-boot`、`out/u-boot.bin` |
| `build-busybox.sh` | 编 BusyBox + 组装根文件系统 + 打包 | `out/rootfs.cpio.gz`、`out/rootfs.cpio.gz.uimg` |
| `build-all.sh` | 上面三个按顺序跑一遍 | —— |
| `run-qemu.sh` | 启动 QEMU | —— |

**想改目录或版本，只改 `config.sh`。**

---

## 它是怎么工作的

```
━━ 宿主机（x86-64）━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   [交叉工具链 arm-linux-gnueabihf-gcc]
        │
        ├── build-kernel.sh   ──►  zImage          （内核镜像）
        │                          vexpress-v2p-ca9.dtb（设备树）
        ├── build-busybox.sh  ──►  busybox ──► 根文件系统 ──► rootfs.cpio.gz(.uimg)
        └── build-uboot.sh    ──►  u-boot          （bootloader）

━━ 搬运 ━━ run-qemu.sh 用 -device loader 把三个文件放进内存固定地址 ━━

━━ 目标机（QEMU 里的 ARM 板子）━━━━━━━━━━━━━━━━━━━━━━━━

   U-Boot 启动
     → bootz：把内核、initrd、设备树交给内核，然后跳转
     → 内核读设备树认识硬件
     → 内核解开 initramfs，当作根文件系统
     → 执行 /init（就是 busybox）
     → 读 /etc/inittab → 起 shell
```

**内存里的地址约定**（`config.sh` 里可以改）：

| 文件 | 地址 |
|---|---|
| 设备树 | `0x61000000` |
| 内核 | `0x62000000` |
| initrd | `0x64000000` |

---

## 前置依赖

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libncurses-dev \
                    libelf-dev libgnutls28-dev uuid-dev swig python3-dev \
                    rsync cpio wget xz-utils device-tree-compiler
```

`uuid-dev` 和 `libgnutls28-dev` 是 U-Boot 的宿主机工具要的，**缺了会在编到
`tools/` 时报 `fatal error: xxx.h: No such file or directory`**。

---

## 踩过的坑（都写进脚本了）

| 症状 | 原因 | 脚本里怎么处理的 |
|---|---|---|
| `networking/tc.c: error: 'TCA_CBQ_MAX' undeclared` | 老源码撞上新内核头文件 | 挑配置时**关掉 `CONFIG_TC`** |
| `sed: can't read .config` | 上一步 `defconfig` 没成功 | 脚本用 `set -e`，**上一步失败立刻停** |
| `Kernel panic: Unable to mount root fs` | 根文件系统里没有 `/init` | 自动 `ln -sf sbin/init init` |
| 同样 panic，但 initrd 明明加载了 | `bootz` 手输的 `:size` 不对 | **用 `mkimage` 包成 uImage**，大小写在头里 |
| `fatal error: uuid/uuid.h` | 缺 `uuid-dev` | 写进 README 的依赖清单 |
| `printenv | head -20` → `syntax error` | **U-Boot 没有管道** | 用 `printenv bootcmd` 这种写法 |

## 已知限制 / 下一步

1. **U-Boot 还是要手敲那四条命令。**
   想做成一键自动启动，可以在 U-Boot 的 defconfig 里加一行
   `CONFIG_BOOTCOMMAND="setenv bootargs console=ttyAMA0; bootz ..."`，重新编译。
2. **文件是 QEMU 用 `-device loader` 摆进内存的。**
   真板子上是 U-Boot 自己从 Flash 或 SD 卡读进来的。
   下一步可以做一个 FAT 格式的虚拟 SD 卡，让 U-Boot 用 `fatload` 读——
   那就和真板子完全一致了。
