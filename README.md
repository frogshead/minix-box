# minix-box

A minimal, low-cost single-board computer that **boots to a Linux console**, built around
the **Allwinner F1C200s** — an ARM926EJ-S (with MMU, so it runs standard Linux) that stacks
**64 MB of DDR inside the package**. With no external memory bus to route, the whole board
collapses to a SoC + SPI flash + microSD + a USB-UART bridge + a couple of regulators on a
cheap 2-layer PCB. Parts are sourced from **LCSC** and fabricated + assembled at **JLCPCB**.

## Repository layout

| Path | What |
|------|------|
| [`hw/`](hw/) | Hardware: KiCad project scaffold, BOM (LCSC part #s), and the comprehensive [design document](hw/docs/minix-box-hw-design.md). |
| [`sw/`](sw/) | Software: a [Buildroot](sw/README.md) setup (in Docker) that builds the U-Boot + kernel + rootfs `sdcard.img`. |

## Quick start

- **Hardware:** open `hw/kicad/minix-box.kicad_pro` in KiCad 8+, import parts by LCSC number
  (`easyeda2kicad`), capture/route, then export Gerbers + BOM + CPL for JLCPCB. Start with
  [`hw/docs/minix-box-hw-design.md`](hw/docs/minix-box-hw-design.md).
- **Software:**

  1. **Build the image** (needs Docker):
     ```
     cd sw && ./build.sh
     ```
     This produces `sw/images/sdcard.img` (and individual bootloader/kernel/DTB files).

  2. **Flash to microSD** (replace `/dev/sdX` with your SD card device):
     ```
     sudo dd if=sw/images/sdcard.img of=/dev/sdX bs=1M status=progress
     sudo sync
     ```

  3. **Boot:** insert the microSD, connect USB-C, and open a serial console at **115200 8N1**.
     Default login: `root` / `root`.

  See [`sw/README.md`](sw/README.md) for build details.

## Status

Design baseline. Several hardware-specific values are deliberately flagged **⚠ VERIFY** in
the design doc and the build files — most importantly the **in-package DDR rail voltage**
(hardware) and the **U-Boot DRAM size = 64 MB** / **device-tree pin-mux** (software). Confirm
these against the F1C200s datasheet and the open Lichee Pi Nano reference before building
hardware or trusting an image. Boot-to-console has not been verified on physical hardware yet.
