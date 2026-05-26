# minix-box — Hardware Design Document

**A minimal, low-cost single-board computer that boots to a Linux console.**

| | |
|---|---|
| SoC | Allwinner **F1C200s** (ARM926EJ-S, ARMv5TEJ, MMU, **64 MB in-package DDR**) |
| Boot | SPI NOR (primary) + microSD (rootfs / dev) |
| Console | Onboard **CH340N** USB-UART bridge over USB-C |
| Power in | USB-C 5 V |
| PCB | 2-layer FR-4, 1.6 mm (JLCPCB) |
| Sourcing | All parts from **LCSC**, fab + SMT assembly at **JLCPCB** |
| Tooling | KiCad 8 (schematic + PCB) |

> **Status:** design baseline. Items flagged ⚠ **VERIFY** must be confirmed against the
> F1C200s datasheet/user manual and the open-source Lichee Pi Nano reference schematic
> **before tape-out**. Getting a power rail or strap wrong can permanently damage the SoC.

---

## 1. Overview & goals

The objective is the *smallest practical PCB that runs mainline Linux to a serial login
prompt*, buildable entirely through JLCPCB's fab + assembly service.

The design philosophy is **"let the chip do the work."** The single decision that makes a
minimal Linux board possible is the SoC. The Allwinner F1C200s integrates **64 MB of DDR
DRAM inside its package (System-in-Package)**, eliminating the external DDR bus — by far
the hardest, highest-risk part of any Linux-capable PCB (length-matching, impedance,
fly-by topology, termination). With DRAM gone from the board, a complete system reduces to
a handful of parts.

### Block diagram

```
                       USB-C #1 (5V + console)
                          |        |
                       VBUS      D+/D-
                          |        |
              +-----------+    +---------+
   5V  ------>| Power     |    | CH340N  |  USB <-> UART bridge
              | 3V3 / 1V1 |    +----+----+
              | / DRAM    |         | UART0 (TX/RX)
              +-----+-----+         |
                    | rails         |
                    v               v
        +-------------------------------------------+
        |             Allwinner F1C200s             |
        |   ARM926EJ-S @ ~533MHz + 64MB DDR (SiP)   |
        |                                           |
        |  SPI0     SDC0     USB-OTG    GPIO/I2C/.. |
        +----+--------+---------+-----------+-------+
             |        |         |           |
        +----v--+ +---v----+ +--v-----+  +--v--------------+
        |W25Q128| |microSD | |USB-C #2|  | 0.1" expansion  |
        |16MB   | |card    | |(OTG)   |  | hdr: I2C/SPI/   |
        |SPI NOR| |        | |        |  | UART/PWM/GPIO   |
        +-------+ +--------+ +--------+  +-----------------+

        Aux: 24MHz xtal (req) | 32.768kHz xtal (opt, RTC)
             Reset button | FEL/recovery button | status LED
```

---

## 2. SoC — Allwinner F1C200s

**Why this chip:**

- **Runs standard Linux.** ARM926EJ-S core implements the ARMv5TEJ ISA *with an MMU*, so
  it boots an ordinary MMU-based Linux kernel and userspace (not just no-MMU µClinux).
- **64 MB DDR in-package.** No external memory bus to route — the chief enabler of a
  2-layer, beginner-routable board. (The 32 MB sibling F1C100s is pin-compatible; choose
  F1C200s for the extra RAM headroom.)
- **Mainline support.** Upstream U-Boot (`suniv` / `suniv_f1c100s_defconfig`) and Linux
  (`arch/arm/boot/dts/suniv-f1c100s*.dtsi`) already support the family.
- **Highly integrated.** On-die SD/MMC, SPI, UART, USB-OTG, I2C/TWI, PWM, audio codec with
  headphone amp, LCD-RGB + CVBS TV-out, CSI camera — most of a usable computer with almost
  no companion silicon.
- **JLCPCB-friendly.** Stocked at LCSC; QFN-88 (0.4 mm pitch) with a center thermal/GND pad
  is within JLCPCB's standard SMT assembly capability.

**Package:** QFN-88, 0.4 mm pitch, exposed center pad — **must** connect to GND and the
ground plane with a via array (thermal + electrical return).

### Peripherals used on this board

| Peripheral | Use |
|---|---|
| SDC0 | microSD card (boot-capable + rootfs) |
| SPI0 | SPI NOR flash (boot) |
| UART0 | Serial console → CH340N |
| USB-OTG | USB-C #2 (gadget/host) |

### Peripherals broken out but optional (populate later if needed)

TWI/I2C, SPI1, PWM, extra UARTs, LCD-RGB (RGB565/666), CVBS composite video,
audio codec line/headphone out, CSI camera input — exposed on the expansion header / test
points, left unpopulated to keep the base board minimal.

---

## 3. Power tree

**Input:** USB-C #1 `VBUS` = **5 V**. Add input reverse/over-voltage protection (series
Schottky or load switch) + bulk cap.

### Rails

| Rail | Nominal | Loads | Suggested regulator |
|---|---|---|---|
| **3V3** | 3.3 V | SoC VCC-IO, VCC-RTC, SPI NOR, microSD, CH340N, codec analog | Buck (e.g. **SY8089**, 2 A) preferred; AMS1117-3.3 LDO acceptable for first spin |
| **1V1 core** | ~1.1 V ⚠ | SoC VDD-CPUX / VDD-SYS (core domain) | Small buck (SY8088/SY8089) or LDO |
| **DRAM** | ⚠ **VERIFY** | In-package DDR supply (VCC-DRAM) | Per datasheet / reference design |

> ⚠ **VERIFY (hard pre-tape-out item): the in-package DDR rail voltage and the power-up
> sequencing.** Do **not** assume a DDR voltage — confirm `VCC-DRAM`, the core voltage, and
> the required rail-up order from the **F1C200s datasheet** and cross-check against the
> **Lichee Pi Nano** open schematic. An incorrect DDR voltage can destroy the SiP DRAM.

### Notes

- Provide a **per-rail current budget** table once regulators are chosen (the F1C200s core
  draws on the order of a few hundred mA at full clock; SD/USB add transient demand).
- Generous local decoupling at every SoC power pin (mix of 100 nF + bulk); place caps as
  close to the pins as the QFN fanout allows.
- Document the **power-on sequence** explicitly in the schematic notes.

---

## 4. Clocks

| Ref | Freq | Required? | Notes |
|---|---|---|---|
| Y1 | **24 MHz** | **Yes** | Main system crystal. Short traces, matched load caps (verify CL), guard ground. |
| Y2 | 32.768 kHz | Optional | RTC crystal — populate only if a battery-backed RTC is needed. |

---

## 5. Boot & strapping

**BROM boot order (Allwinner suniv):** `SDC0` → `SPI0 NOR` → `SPI0 NAND` → `USB-FEL`.

- **microSD on SDC0** — boot-capable *and* the development rootfs medium (easy to reflash by
  swapping cards).
- **SPI NOR (W25Q128, 16 MB) on SPI0** — primary on-board boot device (U-Boot SPL + U-Boot +
  kernel + small rootfs, or just the bootloader that then mounts SD).
- **FEL recovery button (SW2)** — momentary that **pulls the SPI NOR CLK low** while held;
  this corrupts the SPI read so the BROM skips SPI and falls through to SD, then to **USB-FEL**
  (Allwinner's built-in USB recovery mode). Lets you always recover a bricked flash over USB.
- **Reset (SW1)** — RC network + button on `nRESET`. ⚠ **VERIFY** whether the SoC needs an
  external POR/reset supervisor or whether the internal POR suffices.

---

## 6. Console path

```
SoC UART0 (TX/RX, 3.3V) ── CH340N ── USB 2.0 D+/D- ── USB-C #1 ── host PC
```

- **CH340N** — SOP-8 USB-to-UART bridge with **internal oscillator** (no crystal) and very
  few passives → minimal footprint, ideal for this board.
- USB-C #1 **also supplies board power** (VBUS → power tree), so one cable gives both power
  and console.
- Console settings: **115200 8N1**. Appears on the host as `/dev/ttyUSB*` (Linux/macOS) or a
  COM port (Windows).

---

## 7. USB

- SoC **USB-OTG** `DP`/`DM` → **USB-C #2** for gadget (e.g. `g_serial`, RNDIS) or host use.
- Route `DP`/`DM` as a **90 Ω differential pair**, short and matched.
- Add **ESD protection** (low-cap TVS diode array) on the connector side.
- Handle CC pull-downs (Rd, 5.1 kΩ each) on USB-C #2 appropriately for the intended OTG role.

---

## 8. Pin-mux / net assignment

> ⚠ **VERIFY all pin assignments against the F1C200s datasheet pin-mux table** before
> schematic capture. The mappings below are the *typical sunxi* defaults and a starting point.

| Function | Typical port (verify) | Net(s) |
|---|---|---|
| UART0 console | (per datasheet) | `UART0_TX`, `UART0_RX` → CH340N |
| SPI0 (NOR boot) | PC0–PC3 | `SPI0_CLK`, `SPI0_CS`, `SPI0_MISO`, `SPI0_MOSI` |
| SDC0 (microSD) | PF0–PF5 | `SDC0_CLK/CMD/D0..D3` |
| USB-OTG | dedicated pins | `USB_DP`, `USB_DM` |
| Status LED | any free GPIO | `LED_STAT` (kernel heartbeat/trigger) |
| Reset / FEL | `nRESET` / SPI0_CLK | SW1 / SW2 |
| Expansion | free GPIO | I2C/SPI1/UART/PWM/GPIO |

---

## 9. Connectors & expansion

- **J1** USB-C — power (5 V) + console (to CH340N).
- **J2** USB-C — SoC USB-OTG.
- **J3** microSD — push-push (or push-pull) connector on SDC0.
- **Expansion header(s)** — 0.1" (2.54 mm) breaking out 3V3, GND, I2C0, SPI1, a spare UART,
  PWM, and general GPIO for hats/prototyping.
- Optional **test points / pads** for audio (line/HP out), LCD-RGB, and CVBS, left
  unpopulated on the base board.

---

## 10. PCB stackup & layout guidelines

**Stackup:** **2-layer**, 1.6 mm FR-4 (JLCPCB's cheapest option). Feasible specifically
because there is no external DDR bus. *Alternative:* 4-layer (Sig/GND/PWR/Sig) for cleaner
power distribution and EMI margin — recommend if budget allows or if EMI testing matters.

**Guidelines:**

- **QFN-88 fanout:** plan escape routing for the 0.4 mm-pitch perimeter before committing to
  2 layers; most signals fan out on top, returns on the bottom ground pour. The center pad
  ties to GND with a stitched via array (also the SoC's main thermal path).
- **Decoupling:** every power pin gets a local cap, placed as close as the fanout allows.
- **Crystal:** short, symmetric traces; surround with ground; keep noisy signals away.
- **USB diff pairs:** 90 Ω, length-matched, minimal vias, reference a solid plane.
- **Grounding:** continuous ground pour on both layers, stitched with vias; avoid splitting
  return paths under high-speed nets.
- **SD lines:** keep the SDC0 group short and roughly equal; series resistors optional for
  signal integrity.

---

## 11. Manufacturing at JLCPCB

**Workflow:**

1. Capture schematic + lay out PCB in **KiCad 8** (scaffold in `../kicad/`).
2. Pull part **symbols + footprints by LCSC part number** using **`easyeda2kicad`** (or
   `JLC2KiCadLib`). This both saves drawing footprints *and* attaches the LCSC number that
   JLCPCB's assembly service matches against.
3. Export from KiCad: **Gerbers + drill** (fab), **BOM** + **CPL/centroid** (assembly).
4. Upload to JLCPCB: PCB fab + **SMT assembly**.

**Assembly notes:**

- Mark each line **Basic vs Extended** in the BOM. **Basic** parts have no per-part feeder
  setup fee; **Extended** parts (the **F1C200s** is Extended) incur a one-time feeder fee per
  unique part — minimize the count of distinct Extended parts to cut cost.
- QFN-88 with a thermal pad is within JLCPCB standard SMT capability; confirm the footprint's
  paste/stencil aperture for the center pad (windowpane the aperture to avoid float).
- Confirm **live LCSC stock** for every part at order time; have substitutes ready,
  especially for the SoC and regulators.

See `../bom/bom.csv` for the working BOM.

---

## 12. Software bring-up — proving "boots to Linux console"

This is the acceptance path that validates the hardware.

1. **Toolchain:** `arm-linux-gnueabi-` (32-bit ARM, soft/hard-float per Buildroot config).
2. **U-Boot:** mainline. Start from `suniv_f1c100s_defconfig`; adjust for **64 MB** RAM and
   the F1C200s board specifics. Build **SPL + u-boot**.
3. **Linux:** mainline kernel. Base the device tree on
   `arch/arm/boot/dts/suniv-f1c100s*.dtsi`; add a **`minix-box` board DTS** enabling UART0
   console, `mmc0` (SDC0), `spi0` + NOR, `usb-otg`, and the status LED.
4. **Rootfs:** **Buildroot** (smallest path to a login shell + BusyBox).
5. **First bring-up:** use **`sunxi-fel`** over **USB-FEL** to load SPL/U-Boot/kernel
   straight into RAM — no flashing needed to confirm the board is alive. Once verified, write
   U-Boot to **SPI NOR** and/or the kernel + rootfs to **microSD**.
6. **Success criterion:** a **Linux login prompt at 115200 8N1** on the CH340 serial port.

---

## 13. BOM summary

Authoritative list: [`../bom/bom.csv`](../bom/bom.csv). Headline parts:

| Ref | Part | Package | LCSC class |
|---|---|---|---|
| U1 | Allwinner F1C200s | QFN-88 | Extended |
| U2 | Winbond W25Q128JVSIQ (16 MB SPI NOR) | SOIC-8 | Basic |
| U3 | WCH CH340N (USB-UART) | SOP-8 | Basic/Extended |
| U4 | SY8089 buck (3V3) + core-rail regulator | SOT-23-6 | Basic/Extended |
| J1/J2 | USB-C receptacles | SMD | Basic |
| J3 | microSD connector | SMD | Basic |
| Y1 | 24 MHz crystal | SMD | Basic |
| Y2 | 32.768 kHz crystal (optional) | SMD | Basic |

Plus reset/FEL buttons, status LED, ESD diodes, decoupling + load caps, resistors.

---

## 14. References

- **Allwinner F1C200s / F1C100s** datasheet & user manual (Allwinner) — *authoritative for
  power rails, sequencing, and pin-mux.*
- **linux-sunxi.org** — F1C100s wiki page (boot order, FEL, mainline status).
- **Lichee Pi Nano** (Sipeed) — open-hardware F1C100s reference schematic; primary
  cross-check for the power tree and DDR rail.
- **Mainline U-Boot** — `suniv` / `suniv_f1c100s_defconfig`.
- **Mainline Linux** — `arch/arm/boot/dts/suniv-f1c100s*.dtsi`.
- **JLCPCB** — PCB + SMT assembly capabilities; Basic vs Extended parts.
- **`easyeda2kicad`** / **`JLC2KiCadLib`** — import LCSC parts (symbol + footprint) into KiCad.
- **`sunxi-tools`** — `sunxi-fel` USB recovery / first bring-up.
