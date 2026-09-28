# embedded-linux-qemu

从源码构建一套完整的嵌入式 Linux 系统，并在 QEMU 里启动它。

**不用买开发板。** 交叉编译、内核、根文件系统、bootloader——
每个环节都是自己编出来的，不是下载现成的发行版镜像。

## 这个项目展示了什么

- **交叉编译**：用 ARM 工具链在 x86 上编出能在 ARM 上跑的东西
- **从源码构建内核**：`defconfig` → `zImage` + 设备树
- **自己搭根文件系统**：BusyBox + `/init` + `/etc/inittab` + 设备节点 → initramfs
- **bootloader**：编 U-Boot，用 `bootz` 把内核 / initrd / 设备树交给内核
- **真实启动流程**：从 FAT 格式的虚拟 SD 卡读文件，`boot.scr` 自动启动（distro boot）
- **工程化**：每一步都脚本化、可复现，几条命令跑完整套流程

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
| `make-sd-image.sh` | 造一张 FAT 格式的虚拟 SD 卡，把产物和 `boot.scr` 拷进去 | `out/sd.img` |
| `run-qemu-sd.sh` | 从 SD 卡启动（**没有 `-device loader`，而且全自动**） | —— |

**两种启动方式**：

| | `run-qemu.sh` | `run-qemu-sd.sh` |
|---|---|---|
| 文件怎么进内存 | QEMU 用 `-device loader` 摆好 | **U-Boot 从 SD 卡 `load` 进来** |
| 要不要手敲命令 | 要（四条） | **不用，`boot.scr` 自动执行** |
| 像不像真板子 | 有点像（省掉了存储那一步） | **基本一致** |
| 需要 SD 卡驱动 | 不需要 | U-Boot 的 MMC 驱动（QEMU 的 vexpress 有） |

### `boot.scr` 是什么

`make-sd-image.sh` 会先写一个纯文本的 `out/boot.cmd`：

```
setenv bootargs console=ttyAMA0
load mmc 0:1 0x62000000 zImage
load mmc 0:1 0x61000000 vexpress-v2p-ca9.dtb
load mmc 0:1 0x64000000 rootfs.cpio.gz.uimg
bootz 0x62000000 0x64000000 0x61000000
```

再用 `mkimage -T script` 打包成 `boot.scr.uimg`。U-Boot 的 `distro_bootcmd`
会去 FAT 根目录找 `boot.scr.uimg` / `boot.scr`，找到就执行。

**这就是工业界的 "distro boot" 流程**——Ubuntu、Debian 的 ARM 镜像都是这么启动的。

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

1. **`-kernel u-boot` 还是"作弊"。**
   真板子上 U-Boot 住在 Flash 里，由芯片的 ROM 代码加载。QEMU 给不了我们一块
   烧好 U-Boot 的 Flash，所以这一环只能让它代劳。**其余全部真实。**
2. **`run-qemu.sh` 那条路还要手敲命令。** 用 `run-qemu-sd.sh` 就自动了。
3. 下一步可以用 **Buildroot** 把整件事重做一遍，看框架怎么自动化这一切。
