#!/usr/bin/env bash
# dump-flash.sh — dump SPI NOR flash to a file via XIP.
#
# Usage:
#   ./scripts/dump-flash.sh <out.bin> [size_bytes]
#
# Default size is 0x400000 (4 MB, full W25Q32).
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <out.bin> [size_bytes]" >&2
    exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT="$(cd "${HERE}/.." && pwd)"
OPENOCD="${OPENOCD:-${KIT}/riscv-openocd/src/openocd}"

OUT="$(cd "$(dirname "$1")" 2>/dev/null && pwd || pwd)/$(basename "$1")"
SIZE="${2:-0x400000}"

if [[ ! -x "${OPENOCD}" ]]; then
    echo "openocd not found at ${OPENOCD}. Run ./bootstrap.sh first." >&2
    exit 1
fi

exec "${OPENOCD}" \
    -f "${KIT}/configs/openocd-board.cfg" \
    -c "set OUT_PATH ${OUT}" \
    -c "set DUMP_SIZE ${SIZE}" \
    -f "${KIT}/scripts/dump-flash.tcl"
