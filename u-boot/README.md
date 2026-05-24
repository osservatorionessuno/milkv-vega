# U-Boot 2026.04 Milk-V Vega

Vendor U-Boot was a 2020.07-rc2 fork with platform code under
`board/nuclei/hbird/` and a heavyweight per-board `nuclei-hbird.h` header.
Since then U-Boot has moved most configuration into the device tree and
into `defconfig`, so vanilla upstream **U-Boot v2026.04** runs on the
Vega with two small patches:

| Patch | What it adds |
|---|---|
| `0001-board-fisilink-add-Milk-V-Vega-FSL91030M-support.patch` | The new board target (`TARGET_MILKV_VEGA`), `defconfig`, DTS, and a near-empty board glue file. |
| `0002-serial-sifive-peek-and-cache-RX-to-work-around-IP.RX.patch` | Driver fix for the Nuclei UART variant where `IP.RXWM` never fires. |

There is no SPL, no environment, no MMC, no network — by the time U-Boot
runs, [freeloader](../freeloader/) has brought up DDR + caches + UART
and [OpenSBI](../opensbi/) has handed off the FDT in `a1`. U-Boot's only
job is to read a `uImage` from SPI NAND and `bootm` into it.

## Boot chain

```
freeloader (SPI NOR @0x20000000)
   |  set up DDR, caches, UART, copy OpenSBI+U-Boot+DTB into DDR
   v
OpenSBI 1.8.1 (DDR @0x41000000, PLATFORM=generic)
   |  initialize M-mode, set PMP, drop to S-mode at U-Boot entry
   v
U-Boot 2026.04 (DDR @0x41200000)
   |  bootcmd: mtd list && mtd read kernel_nand 0x42000000 0 0x400000 && bootm 0x42000000 - ${fdtcontroladdr}
   v
Linux uImage  (loaded @0x41200000, FDT reused from a1)
```

## What's in patch 0001

A board entry, *not* a SoC port. Almost everything is device-tree-driven:

* `board/fisilink/milkv_vega/Kconfig` — selects `GENERIC_RISCV`, implies
  only the drivers we actually use (`SIFIVE_SERIAL`, `SPI_SIFIVE`,
  `MTD_SPI_NAND`, `CMD_MTD`, `HUSH_PARSER` for `&&` in bootcmd,
  `OF_HAS_PRIOR_STAGE` so the FDT in `a1` is honoured).
* `board/fisilink/milkv_vega/vega.c` — empty `board_init()`. Required
  by the linker, but freeloader and OpenSBI have done the work.
* `configs/milkv_vega_defconfig` — 19 lines. Disables every default-y
  symbol we don't need (`CMD_BOOTI`, `CMD_SF`, `SPI_FLASH`, `EFI_LOADER`).
* `arch/riscv/dts/milkv-vega.dts` — same DTS OpenSBI consumes, with
  the partition layout and SiFive serial/SPI nodes the U-Boot drivers
  bind to. Note `sifive,fifo-depth = <4>` on both SPI controllers:
  the Nuclei FIFOs are 4 entries, not the SiFive default of 8.
* `include/configs/milkv-vega.h` — one line (`CFG_SYS_SDRAM_BASE`).
* `arch/riscv/Kconfig` + `arch/riscv/dts/Makefile` — wire the new
  target into the build.

`u-boot.bin` ends up at ~340 KiB.

## What's in patch 0002

A real driver bug, not Vega-specific: on the Nuclei UART variant the
`IP.RXWM` bit in the interrupt-pending register never asserts even
when RXDATA holds a valid byte. The upstream SiFive driver polls
`IP.RXWM` from `->pending(input)`, so the U-Boot console input loop
never calls `->getc()` and autoboot can never be interrupted.

The fix:
1. In `pending(input)`, peek the RX FIFO. If `RXEMPTY` is clear, the
   read consumed a byte — cache it in `struct sifive_uart_plat` and
   return "input available".
2. In `getc()`, drain the cache first; only if it's empty do we read
   RXDATA again.

On a well-behaved SiFive core `IP.RXWM` asserts as expected, the fast
path returns at the IP check, and the cache is never touched.

## Building

The SDK Makefile change (defconfig name `nuclei_hbird_defconfig` →
`milkv_vega_defconfig`) is in [`Makefile.diff`](Makefile.diff). With
that and the two patches applied to a vanilla U-Boot v2026.04 tree,
`make freeloader` in the SDK produces a working `freeloader.bin`.
