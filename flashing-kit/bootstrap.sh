#!/usr/bin/env bash
# Clone the Nuclei riscv-openocd fork, apply the burst-write patches, build it.
# Idempotent: safe to re-run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/riscv-mcu/riscv-openocd"
# Pinned to the commit the patches were generated against — adjust if you
# rebase the patches onto a newer Nuclei release.
REPO_REF="7b954ec9939d69cf4bd88762f392b63fbebf0285"
SRC_DIR="${HERE}/riscv-openocd"

echo "==> ensuring build deps (macOS via brew, Linux via apt)"
if [[ "$(uname)" == "Darwin" ]]; then
    if ! command -v brew >/dev/null; then
        echo "Install Homebrew first: https://brew.sh" >&2
        exit 1
    fi
    brew list libusb       >/dev/null 2>&1 || brew install libusb
    brew list libftdi      >/dev/null 2>&1 || brew install libftdi
    brew list libtool      >/dev/null 2>&1 || brew install libtool
    brew list automake     >/dev/null 2>&1 || brew install automake
    brew list autoconf     >/dev/null 2>&1 || brew install autoconf
    brew list pkg-config   >/dev/null 2>&1 || brew install pkg-config
elif command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y build-essential libtool autoconf automake \
        texinfo pkg-config libusb-1.0-0-dev libftdi1-dev
fi

if [[ ! -d "${SRC_DIR}/.git" ]]; then
    echo "==> cloning ${REPO_URL}"
    git clone "${REPO_URL}" "${SRC_DIR}"
fi

echo "==> checking out ${REPO_REF}"
git -C "${SRC_DIR}" fetch --all --tags
git -C "${SRC_DIR}" checkout --force "${REPO_REF}"
git -C "${SRC_DIR}" reset --hard "${REPO_REF}"
git -C "${SRC_DIR}" clean -fdx -e build/

echo "==> applying patches"
for p in "${HERE}/patches"/*.patch; do
    echo "    $(basename "$p")"
    git -C "${SRC_DIR}" apply --whitespace=nowarn "$p"
done

echo "==> configuring"
pushd "${SRC_DIR}" >/dev/null
./bootstrap
./configure --enable-ftdi --disable-werror
echo "==> building (this may take a few minutes)"
make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
popd >/dev/null

echo
echo "==> done. binary at: ${SRC_DIR}/src/openocd"
echo "    export OPENOCD=${SRC_DIR}/src/openocd"
