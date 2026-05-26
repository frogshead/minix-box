# minix-box — Linux image build

Builds a bootable Linux image (`sdcard.img` + `u-boot-sunxi-with-spl.bin`) for the
F1C200s board using **Buildroot**, which produces the cross-toolchain, **U-Boot**
(`suniv_f1c100s`), the **Linux kernel** (sunxi/suniv), and a BusyBox **rootfs** in one tree.

Buildroot can't build natively on macOS (it needs Linux and a case-sensitive filesystem),
so everything runs in a **pinned Linux Docker container**. The Buildroot tree and its
`output/` live in a Docker named volume; only the final artifacts are copied to
`sw/images/` on the host.

There are two build paths — use Docker on macOS, or the native script if you're already on
Linux. Both read the pinned Buildroot version from `buildroot.version` and produce the same
artifacts in `sw/images/`. Budget ~20–30 GB disk and ~1–2 h for the first build.

## Build — Docker (any host, required on macOS)

Needs only Docker; all build tools live in the container. The Buildroot tree and `output/`
live in a Docker named volume (avoids macOS's case-insensitive filesystem).

```sh
cd sw
./build.sh               # full build -> sw/images/
./build.sh --defconfig   # fast: just load the defconfig (sanity check, no compile)
./build.sh --shell       # interactive shell in the build container
./build.sh --clean       # drop the Buildroot work volume (keeps the download cache)
```

## Build — native Linux (no Docker)

For a Linux host with standard build tools (the script lists the package to install if any
are missing). The Buildroot tree + `output/` go under `sw/.build/` (gitignored). Do **not**
run as root — Buildroot refuses it.

```sh
cd sw
./build-native.sh                    # full build -> sw/images/
./build-native.sh --defconfig        # fast sanity check (no compile)
./build-native.sh --menuconfig       # Buildroot menuconfig
./build-native.sh --linux-menuconfig # kernel menuconfig (to complete linux.config)
./build-native.sh --clean            # remove the Buildroot tree + output (keeps downloads)
```

Artifacts land in `sw/images/`:
- `sdcard.img` — full microSD image (U-Boot + boot partition + ext4 rootfs)
- `u-boot-sunxi-with-spl.bin` — bootloader for SPI-NOR / FEL
- `zImage`, `*.dtb`

## Flash & boot

**microSD** (replace `diskN` / `mmcblkX` with your card; double-check the device!):

```sh
# macOS
diskutil unmountDisk /dev/diskN
sudo dd if=images/sdcard.img of=/dev/rdiskN bs=4m && sync
# Linux
sudo dd if=images/sdcard.img of=/dev/mmcblkX bs=4M conv=fsync
```

Insert the card, connect **USB-C #1** (power + console), open the serial port at
**115200 8N1** (`screen /dev/tty.usbserial-* 115200`, or `picocom`/`minicom`). You should
see U-Boot then a Linux login prompt (`root` / `root`).

**First bring-up / recovery over USB-FEL** (no card needed) using
[`sunxi-tools`](https://github.com/linux-sunxi/sunxi-tools): hold the FEL button (SW2) while
powering on, then:

```sh
sunxi-fel -v uboot images/u-boot-sunxi-with-spl.bin
# write the bootloader to SPI NOR:
sunxi-fel spiflash-write 0 images/u-boot-sunxi-with-spl.bin
```

## Layout

```
sw/
  build.sh                         Docker build wrapper
  build-native.sh                  native Linux build (no Docker)
  Dockerfile                       pinned Debian + Buildroot host deps
  buildroot.version                pinned Buildroot version (shared by both scripts)
  buildroot-external/              BR2_EXTERNAL tree (name: MINIX_BOX)
    configs/minix-box_defconfig    the Buildroot defconfig
    board/minix-box/               DTS, kernel config, U-Boot fragment, genimage, scripts
  images/                          build output (gitignored)
```

## ⚠ Before trusting the image (hardware-specific, unverified here)

These are flagged in-file and **must be confirmed** before relying on a build — see also
[`../hw/docs/minix-box-hw-design.md`](../hw/docs/minix-box-hw-design.md):

- **U-Boot DRAM size = 64 MB** for F1C200s (vs 32 MB Lichee-Nano default) —
  `board/minix-box/uboot.fragment`.
- **Device-tree pin-mux** (uart0/spi0/mmc0/usb, status LED) vs the F1C200s datasheet —
  `board/minix-box/suniv-f1c200s-minix-box.dts`.
- **Kernel config** is a *starter* — complete and validate it with `make linux-menuconfig`
  + `make linux-update-defconfig` (suniv is ARMv5TE, not covered by the generic v7
  `sunxi_defconfig`) — `board/minix-box/linux.config`.
- Pinned **Buildroot / U-Boot / kernel versions** — bump to current working releases. If
  mainline misbehaves on suniv, fall back to the proven
  [`unframework/licheepi-nano-buildroot`](https://github.com/unframework/licheepi-nano-buildroot)
  forks (U-Boot `v2021.01-f1c100s-4`, kernel `v5.11-nano-4`).

Reference: [`aodzip/buildroot-tiny200`](https://github.com/aodzip/buildroot-tiny200)
(F1C100s/F1C200s-specific external tree).
