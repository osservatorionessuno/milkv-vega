#!/usr/bin/env bash
# flash.sh — front-end for flashing a sector range of the SPI NOR.
#
# Usage:
#   ./scripts/flash.sh <image.bin> <first_sector> <last_sector>
#
# Example — full 1 MB freeloader (16 sectors):
#   ./scripts/flash.sh freeloader.bin 0 15
#
# Example — whole 4 MB W25Q32:
#   ./scripts/flash.sh whole_chip.bin 0 63
#
# Example — only sector 8:
#   ./scripts/flash.sh freeloader.bin 8 8
#
# The file must cover the *whole* flash region addressed by the sector range,
# starting at byte 0 = sector 0. Pad with 0xFF if your image is smaller than
# the chip.
set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <image.bin> <first_sector> <last_sector>" >&2
    exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT="$(cd "${HERE}/.." && pwd)"
OPENOCD="${OPENOCD:-${KIT}/riscv-openocd/src/openocd}"

IMG="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
FIRST="$2"
LAST="$3"

if [[ ! -x "${OPENOCD}" ]]; then
    echo "openocd not found at ${OPENOCD}. Run ./bootstrap.sh first." >&2
    exit 1
fi
if [[ ! -f "${IMG}" ]]; then
    echo "image not found: ${IMG}" >&2
    exit 1
fi

exec "${OPENOCD}" \
    -f "${KIT}/configs/openocd-board.cfg" \
    -c "set IMG_PATH ${IMG}" \
    -c "set FIRST_SECTOR ${FIRST}" \
    -c "set LAST_SECTOR ${LAST}" \
    -f "${KIT}/scripts/flash-region.tcl"
