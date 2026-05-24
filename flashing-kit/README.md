# flashing-kit

Recover and reflash the SPI NOR on a MilkV Vega over JTAG with a patched
Nuclei OpenOCD.

## Layout

| Path | Purpose |
|---|---|
| `bootstrap.sh` | Clone Nuclei `riscv-openocd`, apply patches, build. |
| `patches/01-nuspi-burst-write.patch` | NUSPI slow-path: drop per-byte FIFO poll. |
| `patches/02-riscv013-burst-helper.patch` | RV0.13 driver: bulk DMI writes via `abstractauto`. |
| `configs/openocd-board.cfg` | FTDI pinout + `work-area-size 0` (forces slow path). |
| `scripts/flash-region.tcl` | Unlock, erase, write, verify a sector range. |
| `scripts/dump-flash.tcl` | Read flash back to a file. |
| `scripts/unlock-and-erase.tcl` | Status-register unlock + erase. |
| `scripts/_common.tcl` | NUSPI register helpers, `w25q_unlock`. |

## Build

```sh
./bootstrap.sh
export OPENOCD=$PWD/riscv-openocd/src/openocd
```

## Flash

```sh
# Full 1 MB freeloader (sectors 0..15)
./scripts/flash.sh freeloader.bin 0 15

# Whole 4 MB W25Q32 (sectors 0..63)
./scripts/flash.sh image_4M.bin   0 63

# Single sector
./scripts/flash.sh freeloader.bin 8 8
```

The file's offset 0 maps to sector 0 on the chip; pad with `0xFF` if shorter
than the range.

## Diff flashing

```sh
./scripts/dump-flash.sh /tmp/cur.bin 0x400000
./scripts/sector-diff.sh /tmp/cur.bin new.bin     # prints changed sector indices
./scripts/flash.sh new.bin <first> <last>
```

## UART

Console on the second FTDI channel, 115200-8N1. macOS device:
`/dev/cu.usbserial-*`.

```sh
> /tmp/uart.log
python3 - /dev/cu.usbserial-XXXX 115200 /tmp/uart.log <<'PY' &
import serial, sys
s = serial.Serial(sys.argv[1], int(sys.argv[2]), timeout=0.1)
with open(sys.argv[3], 'wb') as f:
    while True:
        b = s.read(256)
        if b: f.write(b); f.flush()
PY
# power-cycle, then:
LC_ALL=C tr -d -c '[:print:]\n\r\t' < /tmp/uart.log
```

## Recovery details

- **Slow path.** `work-area-size 0` tells `nuspi.c` to skip the ILM
  algorithm and write the NUSPI registers (`TXDATA`/`FCTRL`/`CSMODE` at
  `0x10014000`) directly over JTAG/DMI.
- **Status-register unlock.** Fresh W25Q32JV reports `SR1=0xC0`, `SR2=0x7E`;
  all programs are NAKed. Volatile `WREN` (`0x50`) + `WRSR` (`0x01 0x00 0x00`)
  + `WRSR2` (`0x31 0x00`) clears it for the session.
- **Burst writes.** Patch 1 removes the per-byte FIFO-full read. Patch 2 adds
  `riscv013_write_burst_to_addr()` which loads `sw s1, 0(s0); ebreak` into
  progbuf, enables `DM_ABSTRACTAUTO.autoexecdata`, and queues N×`DM_DATA0`
  writes per `riscv_batch` — one USB round-trip per batch instead of per byte.
  ≈ 9 KB/s → ≈ 85 KB/s.

## Gotchas

- JTAG ≤ 8 MHz. Above ~20 MHz the DMI bus corrupts.
- Status-register unlock is per-power-cycle.
- Reading `0x40000000+` before DDR init wedges the AXI bus; only power cycle
  recovers.
