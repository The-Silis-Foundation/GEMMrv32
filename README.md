# GEMMrv32 Basys 3: Bare-Metal RISC-V SoC with Systolic GEMM on Digilent Basys 3

[![Target Platform](https://img.shields.io/badge/FPGA-Digilent%20Basys%203%20(XC7A35T)-orange?style=flat-square)](https://digilent.com/reference/programmable-logic/basys-3/start)
[![ISA](https://img.shields.io/badge/ISA-RV32IM-green?style=flat-square)](https://riscv.org)
[![System Clock](https://img.shields.io/badge/Clock-50.0%20MHz%20MMCM-blue?style=flat-square)]()
[![Internal Memory](https://img.shields.io/badge/SRAM-128%20KB%20(64K%20IMEM%20%2B%2064K%20DMEM)-yellow?style=flat-square)]()
[![Author](https://img.shields.io/badge/Author-JeromeAntonyRobin-black?style=flat-square)](https://github.com/JeromeAntonyRobin)

A clean, production-ready bare-metal SoC implementation of the **NEORV32 RISC-V processor** equipped with a custom **8x8 Systolic-Array GEMM Coprocessor**, **256-bit wide DMA memory crossbar**, **VGA raster core**, and **debounced PS/2 keyboard receiver** tailored specifically for the **Digilent Basys 3 FPGA (`xc7a35tcpg236-1`)**.

---

## Branch Overview: `basys`

This branch contains the **clean Basys 3 SoC baseline**, including board wrappers, constraints, pure Vivado batch TCL scripts, the **pre-synthesized tracked bitstream**, and standard hardware bringup demos.

```
+-----------------------------------------------------------------------------------+
|                        NEORV32 BASYS 3 SoC MEMORY MAP                            |
|                                                                                   |
|  0x00000000 - 0x0000FFFF : 64 KB Instruction Memory (IMEM, on-chip BRAM)          |
|  0x80000000 - 0x8000FFFF : 64 KB Data Memory (DMEM, on-chip BRAM)                 |
|  0x90000000 - 0x90004B00 : 19,200 Bytes Dual-Port VGA Framebuffer (160x120 @ 8bpp)|
|  0x90010000 - 0x900103FF : 256 x 12-bit RGB Color Lookup Table (Palette CLUT)    |
|  0x90020000 - 0x9002000F : Debounced PS/2 Keyboard Controller FIFO               |
|  0xFFEA0000 - 0xFFEA001F : Custom 8x8 Systolic GEMM Coprocessor Registers (CFS) |
|  0xFFFFFE00 - 0xFFFFFFFF : NEORV32 Internal Bootloader ROM                        |
+-----------------------------------------------------------------------------------+
```

---

## Hardware Utilization on Artix-7 35T

Implementation report from Vivado batch implementation on `xc7a35tcpg236-1`:

| Resource Type | Used | Total Available | Utilization % | Architectural Notes |
|---|:---:|:---:|:---:|---|
| **Block RAM (BRAM36)** | **43.5** | **50** | **87.0%** | IMEM (16), DMEM (16), DMA (8), VRAM (5), FIFOs (1) |
| **Slice LUTs** | **9,420** | **20,800** | **45.3%** | Logic, 8x8 systolic multiplier cells, memory crossbar |
| **Slice Registers** | **5,910** | **41,600** | **14.2%** | Pipeline stages, DMA counters, Wishbone registers |
| **DSP48E1 Slices** | **0** | **90** | **0.0%** | Synthesizer heuristic maps 8-bit signed multipliers to LUTs |
| **MMCM / PLL** | **1** | **5** | **20.0%** | Generates locked 50.0 MHz system clock from 100 MHz oscillator |

---

## Hardware Jumper & Reset Configuration

1. **`JP1` (Programming Mode Selector)**:
   * **Set to `JTAG` (bridge the center two pins).**
   * *Critical:* If set to `USB`, the host port enters thumb-drive mode and disables keyboard input.
2. **`JP2` / `JP3` (Power Source Selector)**:
   * **Set to `USB`** (power drawn from micro-USB cable `J4`).
3. **Reset Buttons**:
   * **`btnC` (Center push button `U18`):** Soft CPU Reset (restarts the NEORV32 bootloader without wiping FPGA SRAM).
   * **`PROG` (Red button near top-left):** Reconfigures the FPGA SRAM from flash.

---

## 1-Click Pure TCL Automation

No platform-specific scripts required. All commands run natively through Vivado:

### 1. 1-Click JTAG Bitstream Programming
The pre-synthesized bitstream [`sw/basys/build/neorv32_basys3.bit`](sw/basys/build/neorv32_basys3.bit) is tracked directly in Git:
```bash
vivado -mode batch -source sw/basys/program_jtag.tcl
```
*Auto-detects connected Basys 3 hardware target and programs the FPGA in ~3 seconds.*

### 2. Synthesize & Implement From Source
To synthesize the complete design, generate timing reports, and write bitstream:
```bash
vivado -mode batch -source sw/basys/build_basys3.tcl
```

### 3. Non-Volatile QSPI Flash Programming
To flash [`sw/basys/build/neorv32_basys3.bin`](sw/basys/build/neorv32_basys3.bin) to onboard Macronix SPI flash:
```bash
vivado -mode batch -source sw/basys/flash_basys3.tcl
```

---

## Included Firmware Demos

Compile with bare-metal RISC-V GCC (`riscv64-unknown-elf-gcc`):

* **[`sw/example/demo_blink_led/`](sw/example/demo_blink_led/)**: Baseline GPIO verification (blinks onboard LEDs `LD0..LD15` at 2 Hz).
* **[`sw/example/demo_gemm/`](sw/example/demo_gemm/)**: 8x8 Systolic GEMM hardware verification and cycle speedup benchmark against software math.
* **[`sw/example/demo_gpu/`](sw/example/demo_gpu/)**: VGA color bars, test patterns, and interactive serial/keyboard console.
* **[`sw/example/hello_world/`](sw/example/hello_world/)**: Simple UART0 print verification.

---

## Technical Documentation Pointers

* **Master Hardware Specification:** [`docs/GEMMRV32_SYSTEM_SPECIFICATION.md`](docs/GEMMRV32_SYSTEM_SPECIFICATION.md)
  * Section 1: System-Level Overview & High-Level Block Diagram
  * Section 2: Complete Address & Memory Architecture
  * Section 3: Hardware Peripheral & Coprocessor VHDL Specifications
  * Section 5: Portability & Reproducibility Guide for Basys 3
* **UART Bootloader & Hardware Debug Report:** [`docs/HARDWARE_DEBUG_REPORT.md`](docs/HARDWARE_DEBUG_REPORT.md)

---

## Repository Branch Directory

* [`master`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/master): Main index and baseline repository snapshot.
* [`pure-rtl`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/pure-rtl): Board-agnostic VHDL core IP library (NEORV32 + GEMM + DMA + VGA + PS/2).
* [`nexys`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/nexys): Digilent Nexys A7 100T TinyML platform with TensorFlow Lite Micro & LeNet.
* [`basys`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/basys): **(You are here)** Clean Basys 3 SoC baseline with tracked bitstream and pure TCL flow.
* [`basys-doom`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/basys-doom): Complete 3D DOOM gaming platform.
