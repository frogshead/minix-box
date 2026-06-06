# minix-box — hardware

A minimal, low-cost single-board computer that **boots to a Linux console**, built around
the **Allwinner F1C200s** (ARM926EJ-S with MMU and **64 MB DDR stacked in-package**, so the
PCB has no external memory bus to route). Parts are sourced from **LCSC** and the board is
fabricated + assembled at **JLCPCB**.

| | |
|---|---|
| SoC | Allwinner F1C200s (QFN-88, 64 MB SiP DDR) |
| Boot | SPI NOR (primary) + microSD (rootfs/dev) |
| Console | Onboard CH340N USB-UART over USB-C, 115200 8N1 |
| Power | USB-C 5 V |
| PCB | 2-layer FR-4, 1.6 mm |

## Layout

```
docs/minix-box-hw-design.md   The comprehensive hardware design document — read this first
bom/bom.csv                   Working BOM (LCSC part numbers, Basic/Extended flags)
kicad/                        KiCad 8 project scaffold (open minix-box.kicad_pro)
kicad/libraries/              Place imported LCSC symbols/footprints here
fab/                          Gerber + CPL output (generated later)
```

## Working in KiCad

The `kicad/` files are a **scaffold**, not a finished design: a valid empty project, an
empty root schematic, an empty 2-layer board, and library tables pointing at
`kicad/libraries/`. Schematic capture and PCB layout are done in the **KiCad 8 GUI**.

1. Open `kicad/minix-box.kicad_pro` in KiCad 8.
2. Import part symbols + footprints **by LCSC part number** into `kicad/libraries/` using
   [`easyeda2kicad`](https://github.com/uPesy/easyeda2kicad.py) (or `JLC2KiCadLib`). This
   keeps the LCSC number attached, which JLCPCB's assembly service matches against.
3. Capture the schematic, lay out the PCB, then export **Gerbers + drill** and **BOM + CPL**
   into `fab/` for upload to JLCPCB.

## Software (boot proof)

Mainline U-Boot (`suniv_f1c100s_defconfig`, adjusted for 64 MB) + mainline Linux (DTS based
on `suniv-f1c100s`) + a Buildroot rootfs. First bring-up via `sunxi-fel` over USB-FEL.
**Success = a Linux login prompt on the CH340 serial port.** Details in the design document.

## Reference designs

The **CherryPi F1C200S** is a similar F1C200s-based board with a publicly available schematic
and community documentation. Useful as a hardware reference for the minix-box since it shares
the same SoC (with in-package DDR), SPI flash, and SD card boot design.

- [CherryPi-F1C200S schematic (PDF)](https://linux-sunxi.org/File:CherryPi-F1C200S.pdf)
- [CherryPi-F1C200S wiki page](https://wikidevi.wi-cat.ru/CherryPi-F1C200S)
- [CNX Software overview](https://www.cnx-software.com/2022/02/03/more-allwinner-f1c200s-arm9-boards-mangopi-r3-and-cherrypi-f1c200s/)

The **LC Tech Pi F1C200s** is the board whose U-Boot defconfig (`lctech_pi_f1c200s`) we use:

- [Lctech Pi F1C200s — linux-sunxi.org](https://linux-sunxi.org/Lctech_Pi_F1C200s)
- [LC-PI-200S — LCWIKI](http://wiki.lctech.cc/index.php?title=LC-PI-200S)

**F1C200s datasheets (Allwinner):**

- [F1C200s Datasheet v1.1 (PDF)](https://linux-sunxi.org/images/5/5e/Allwinner_F1C200s_Datasheet_V1.1.pdf)
- [F1C200s User Manual v1.2 (PDF)](https://linux-sunxi.org/images/5/56/Allwinner_F1C200s_User_Manual_V1.2.pdf)

## ⚠ Before tape-out

Confirm the items flagged **VERIFY** in the design document against the F1C200s datasheet and
the open-source **Lichee Pi Nano** and **CherryPi F1C200S** reference schematics — above all
the **in-package DDR rail voltage and power-up sequencing**. A wrong rail can destroy the SoC.
