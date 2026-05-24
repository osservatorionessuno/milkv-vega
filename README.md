# milkv-vega

Notes and tooling for the [MilkV Vega](https://milkv.io/) RISC-V SBC.

## Board

- SoC: Fudan Microelectronics **FSL91030M** (Nuclei UX600/UX608 core, RV64GC)
- 256 MiB DDR3, 128 MiB SLC NAND, 4 MiB SPI NOR (W25Q32JV) at `0x20000000`

## Upstream

- Vendor SDK: <https://github.com/milkv-vega/vega-buildroot-sdk>
- Vendor files repo: <https://github.com/milkv-vega/vega-files>

## Datasheets

| English name | Upstream file |
|---|---|
| FSL91030M chip datasheet (Rev G) | [`FSL91030M芯片数据手册-G版本.pdf`](https://github.com/milkv-vega/vega-files/blob/main/development-documentation/FSL91030M%E8%8A%AF%E7%89%87%E6%95%B0%E6%8D%AE%E6%89%8B%E5%86%8C-G%E7%89%88%E6%9C%AC.pdf) |
| FSL91030M register reference (Rev D) | [`FSL91030M寄存器说明书-D.pdf`](https://github.com/milkv-vega/vega-files/blob/main/development-documentation/FSL91030M%E5%AF%84%E5%AD%98%E5%99%A8%E8%AF%B4%E6%98%8E%E4%B9%A6-D.pdf) |
| FSL91030(M) SoC user manual (V10) | [`FSL91030(M)芯片SoC使用说明书_V10.pdf`](https://github.com/milkv-vega/vega-files/blob/main/development-documentation/FSL91030(M)%E8%8A%AF%E7%89%87SoC%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E%E4%B9%A6_V10.pdf) |
| FSL91030(M) chip architecture (V12) | [`FSL91030(M)芯片原理文档_V12.pdf`](https://github.com/milkv-vega/vega-files/blob/main/development-documentation/FSL91030(M)%E8%8A%AF%E7%89%87%E5%8E%9F%E7%90%86%E6%96%87%E6%A1%A3_V12.pdf) |
| FSL91030(M) test board & software manual (V16) | [`FSL91030(M)芯片测试板及其软件使用手册_V16.pdf`](https://github.com/milkv-vega/vega-files/blob/main/development-documentation/FSL91030(M)%E8%8A%AF%E7%89%87%E6%B5%8B%E8%AF%95%E6%9D%BF%E5%8F%8A%E5%85%B6%E8%BD%AF%E4%BB%B6%E4%BD%BF%E7%94%A8%E6%89%8B%E5%86%8C_V16.pdf) |
| Vega schematic v1.1 | [`vega_schematic_v1.1.pdf`](https://github.com/milkv-vega/vega-files/blob/main/hardware/vega_schematic_v1.1.pdf) |
| Vega mechanical drawing | [`vega-mechanical-drawing.pdf`](https://github.com/milkv-vega/vega-files/blob/main/hardware/vega-mechanical-drawing.pdf) |

## Toolchain

- Compiler: [Nuclei RISC-V GNU toolchain](https://github.com/riscv-mcu/riscv-gnu-toolchain)
- Debugger: [Nuclei riscv-openocd fork](https://github.com/riscv-mcu/riscv-openocd)
- Core spec: [Nuclei RISC-V ISA spec](https://www.nucleisys.com/upload/files/doc/Nuclei_RISC-V_ISA_Spec.pdf).

## Flashing

The vendor flow writes the SPI NOR through an algorithm loaded into ILM
(`0x80000000`) at `flash write_image` time. For some reason ILM writes are
silently dropped, so the algorithm runs garbage and times out. Trying to
initialize memory before running the flashing sequence also fails.

### Recovery

The [`flashing-kit/`](flashing-kit/) directory contains a patched build of
Nuclei OpenOCD and Tcl scripts that:

- Force OpenOCD onto the slow path (`work-area-size 0`) so writes go over
  JTAG/DMI directly to the NUSPI registers at `0x10014000`.
- Issue a volatile `WREN` + `WRSR`/`WRSR2` over JTAG before any erase, to
  clear the status-register lock.
- Batch DMI writes via `abstractauto.autoexecdata` so one USB transaction
  programs many bytes (≈ 9× speedup over the naive slow path).

See [`flashing-kit/README.md`](flashing-kit/README.md) for build and usage.
