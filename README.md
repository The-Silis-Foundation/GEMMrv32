# GEMMrv32: Hardware-Accelerated RISC-V SoC & Systolic Coprocessor Platform

[![ISA](https://img.shields.io/badge/ISA-RV32IM%20RISC--V-green?style=flat-square)](https://riscv.org)
[![Hardware Accelerator](https://img.shields.io/badge/Accelerator-8x8%20Systolic%20GEMM-brightgreen?style=flat-square)]()
[![FPGA Platforms](https://img.shields.io/badge/Platforms-Basys%203%20%7C%20Nexys%20A7-orange?style=flat-square)]()
[![Video Architecture](https://img.shields.io/badge/Video-VGA%20160x120%20%26%20320x200%20%40%2060Hz-purple?style=flat-square)]()
[![Author](https://img.shields.io/badge/Author-JeromeAntonyRobin-black?style=flat-square)](https://github.com/JeromeAntonyRobin)

**GEMMrv32** is a modular, hardware-accelerated bare-metal SoC built on the [NEORV32](https://github.com/stnolting/neorv32) RISC-V processor. It extends the core with a custom **8x8 Systolic-Array GEMM Coprocessor**, a **256-bit wide DMA memory crossbar**, a **dedicated dual-port VGA rasterizer**, and a **debounced PS/2 keyboard receiver**.

The repository is organized into **three specialized, decoupled branches** to serve different target platforms and research domains.

---

## Repository Branch Directory & Portal

Navigate directly to the branch tailored for your use case:

```
                                  GEMMrv32 Master
                                  (Pure VHDL Core)
                                         │
                        ┌────────────────┴────────────────┐
                        ▼                                 ▼
                     basys3                            nexysa7
                  (Basys 3 35T                     (Nexys A7 100T
                Clean SoC + .bit)                TinyML SoC + LeNet)
```

| Branch | Target Platform | Primary Focus & Capabilities | Jump Link |
|---|---|---|:---:|
| **`master`** | **Vendor-Agnostic ASIC / FPGA** | **Pure VHDL-2008 Hardware IP Core Library**: Completely stripped of board-specific constraints and demo firmware. Contains the NEORV32 core, 8x8 systolic GEMM coprocessor (`neorv32_cfs.vhd`), 256-bit DMA crossbar, wide BRAM, VGA core, PS/2 receiver, and simulation testbenches (`sim/`). Ready for drop-in synthesis or ASIC tape-out. | [**Explore `master`**](https://github.com/The-Silis-Foundation/GEMMrv32/tree/master) |
| **`basys3`** | **Digilent Basys 3 (`xc7a35tcpg236-1`)** | **Clean Basys 3 SoC Baseline**: 50.0 MHz MMCM system clock, 64 KB IMEM + 64 KB DMEM, pure Vivado batch TCL scripts (`build_basys3.tcl`, `program_jtag.tcl`, `flash_basys3.tcl`), basic bringup demos, and the **tracked bitstream** (`sw/basys/build/neorv32_basys3.bit`). | [**Explore `basys3`**](https://github.com/The-Silis-Foundation/GEMMrv32/tree/basys3) |
| **`nexysa7`** | **Digilent Nexys A7 (`xc7a100tcsg324-1`)** | **Edge AI & TinyML Platform**: Full bare-metal TensorFlow Lite Micro (TFLM) runtime tree, 23-class color classification CNN (`demo_lenet`), and GEMM benchmark achieving a **14.7x measured end-to-end hardware inference speedup**. | [**Explore `nexysa7`**](https://github.com/The-Silis-Foundation/GEMMrv32/tree/nexysa7) |

> [!NOTE]
> The bare-metal 3D DOOM workstation has been decoupled into its dedicated repository: [**DOOM-on-GEMMrv32**](https://github.com/JeromeAntonyRobin/DOOM-on-GEMMrv32), which links the `basys3` hardware SoC platform as a git submodule.

---

## System Architecture

```
+-----------------------------------------------------------------------------------+
|                            GEMMrv32 SYSTEM BLOCK DIAGRAM                          |
|                                                                                   |
|   +---------------------------------------------------------------------------+   |
|   |                        NEORV32 RV32IM CPU CORE                            |   |
|   |          Instruction Cache (i-cache)  |  Cycle Counters (mcycle)          |   |
|   +---------------------------------------------------------------------------+   |
|          │                                                       │                |
|          │ CFS Coprocessor Interface (0xFFEA0000)                │ Wishbone / XBUS|
|          ▼                                                       ▼                |
|   +---------------------------------------------------------------------------+   |
|   |                    256-bit Wide DMA Interconnect Crossbar                 |   |
|   +---------------------------------------------------------------------------+   |
|          │                                   │                   │                |
|          ▼                                   ▼                   ▼                |
|   +--------------------------+     +-------------------+   +------------------+   |
|   |  8x8 Systolic GEMM Unit  |     |  Dedicated 256-bit|   |  VGA Framebuffer |   |
|   |  - 64 MAC ops/clock      |     |  Tensor BRAM      |   |  & Palette CLUT  |   |
|   |  - 66x Vector Speedup    |     |  (Zero Stalls)    |   |  (12-bit RGB)    |   |
|   +--------------------------+     +-------------------+   +------------------+   |
|                                                                  │                |
|                                                                  ▼                |
|                                                            VGA Output (J1)        |
+-----------------------------------------------------------------------------------+
```

---

## Master Memory Map

| Address Region | Size | Description | Hardware Master / Port |
|---|:---:|---|---|
| `0x00000000 - 0x0000FFFF` | 64 KB | **Instruction Memory (IMEM)** | CPU Fetch Bus |
| `0x80000000 - 0x8000FFFF` | 64 KB | **Data Memory (DMEM)** | CPU Load/Store Bus |
| `0x90000000 - 0x90004B00` | 19.2 KB | **VGA Dual-Port Framebuffer** (160x120 @ 8bpp) | XBUS Slave / Raster Scanout Port |
| `0x90010000 - 0x900103FF` | 1 KB | **VGA Color Palette (CLUT)** (256 entries x 12-bit RGB) | XBUS Slave / DAC Output Stage |
| `0x90020000 - 0x9002000F` | 16 B | **PS/2 Keyboard Receiver FIFO** | XBUS Slave |
| `0xFFEA0000 - 0xFFEA001F` | 32 B | **8x8 Systolic GEMM Control Registers** | CFS Memory-Mapped Port |
| `0xFFFFFE00 - 0xFFFFFFFF` | 512 B | **NEORV32 Internal Bootloader ROM** | CPU Fetch Bus |

---

## Technical Documentation Suite

The complete engineering documentation is located in [`docs/`](docs/):

* **[`docs/GEMMRV32_SYSTEM_SPECIFICATION.md`](docs/GEMMRV32_SYSTEM_SPECIFICATION.md)**:
  * Section 1: System-Level Overview & High-Level Block Diagram
  * Section 2: Complete Address & Memory Architecture
  * Section 3: Hardware Peripheral & Coprocessor VHDL Specifications
  * Section 4: Hardware Coprocessor Drivers & C API
  * Section 5: Portability & Reproducibility Guide for Basys 3
  * **Section 6.1: The 32-bit vs 8-bit VRAM Write Ghosting Anomaly & Resolution**
  * **Section 6.2: The DOOM v3 4bpp Stride, Write-Only Bus Trap & Hall-of-Mirrors Glitch**
* **[`docs/DOOM_GRAPHICS_PIPELINE.md`](docs/DOOM_GRAPHICS_PIPELINE.md)**:
  * Bare-metal 3D raycasting DDA math, texture coordinate mapping, 1D Z-Buffer, and Id Software BSP treelinedef architecture.
* **[`docs/HARDWARE_DEBUG_REPORT.md`](docs/HARDWARE_DEBUG_REPORT.md)**:
  * Detailed diagnostic report resolving the `ERROR_EXCEPTION 0x7 0xFFE006A8` bootloader framing exception and UART streaming synchronization.

---

## Reproducibility & Portability

1. **Pure TCL Automation:** Zero Windows-specific `.ps1` or `.bat` dependencies in the synthesis tree. Batch synthesis and hardware programming run through native Vivado TCL scripts:
   * `sw/basys/build_basys3.tcl` (batch synthesis & bitstream export)
   * `sw/basys/program_jtag.tcl` (1-click JTAG programming of tracked `neorv32_basys3.bit`)
   * `sw/basys/flash_basys3.tcl` (non-volatile SPI flash programming)
2. **Standard RISC-V GCC Toolchain:** Compiles with any standard `rv32im_zicsr_zifencei` toolchain using relative, portable makefiles.
3. **Tracked Hardware Bitstreams:** Pre-synthesized bitstreams are version-controlled directly in Git, allowing immediate hardware testing on physical Basys 3 boards without awaiting local synthesis.
