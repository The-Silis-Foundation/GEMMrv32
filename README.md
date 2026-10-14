# GEMMrv32 Pure RTL: Portable Hardware IP Core Library

[![HDL](https://img.shields.io/badge/Language-VHDL--2008-blue?style=flat-square)]()
[![Target](https://img.shields.io/badge/Target-Vendor--Agnostic%20FPGA%20%2F%20ASIC-brightgreen?style=flat-square)]()
[![ISA](https://img.shields.io/badge/ISA-RV32IM%20RISC--V-green?style=flat-square)](https://riscv.org)
[![Status](https://img.shields.io/badge/Verification-Synthesizable%20%26%20Simulation%20Tested-purple?style=flat-square)]()
[![Author](https://img.shields.io/badge/Author-JeromeAntonyRobin-black?style=flat-square)](https://github.com/JeromeAntonyRobin)

This branch contains the **pure, board-agnostic hardware RTL core IP library**. It is completely decoupled from any target FPGA board files, software source trees, or toolchain-specific build artifacts, making it immediately drop-in ready for ASIC synthesis, FPGA EDA suites (Vivado, Quartus, Libero), or RTL simulation environments (GHDL, ModelSim, VCS, Verilator).

---

## Branch Overview: `pure-rtl`

```
rtl/
├── core/                                # Full NEORV32 RV32IM Processor & Custom IP
│   ├── neorv32_cfs.vhd                  # 8x8 Systolic-Array GEMM Coprocessor (CFS)
│   ├── neorv32_memory_crossbar.vhd      # 2-Master (CPU + DMA) 256-bit Interconnect
│   ├── neorv32_wide_bram.vhd            # 256-bit Wide Port Tensor Block RAM Buffer
│   ├── neorv32_vga.vhd                  # Dual-Port VGA Raster Core & 12-bit Palette CLUT
│   ├── neorv32_ps2.vhd                  # PS/2 Keyboard Receiver with Deglitch & 16B FIFO
│   ├── neorv32_cpu.vhd                  # Core ALU, Register File, and Control Logic
│   └── neorv32_*.vhd                    # Bus Interfaces, MTIME, UART, Timers, Caches
├── system_integration/                  # System Busses & Packaging
│   ├── neorv32_vivado_ip.tcl            # Vivado IP-XACT Packaging Generator
│   ├── xbus2axi4_bridge.vhd             # NEORV32 XBUS to AXI4 Bus Protocol Bridge
│   └── neorv32_litex_core_complex.vhd   # LiteX SoC Integration Wrapper
sim/                                     # Simulation Testbenches
└── neorv32_tb.vhd                       # Cycle-accurate top-level simulation testbench
```

---

## Core IP Modules & Specifications

### 1. 8x8 Systolic GEMM Coprocessor (`rtl/core/neorv32_cfs.vhd`)
* **Array Geometry:** $8 \times 8$ 2D mesh systolic array (64 processing elements).
* **Arithmetic:** 8-bit signed integer operands with 32-bit signed accumulation ($C_{i,j} \leftarrow C_{i,j} + A_{i,k} \times B_{k,j}$).
* **Throughput:** 64 Multiply-Accumulate (MAC) operations per clock cycle.
* **Control Register Interface:** Memory-mapped registers via NEORV32 CFS port (`0xFFEA0000`):
  * `REG[0..2]`: 32-bit DMA Base Addresses for Matrices $A$, $B$, and $C$.
  * `REG[3..5]`: Row Strides for Matrices $A$, $B$, and $C$.
  * `REG[6]`: Control / Status register (Start, Clear, Store, Status Done).
  * `REG[7]`: Tile dimensions ($M, K, N \le 8$).

### 2. 256-bit Wide DMA Interconnect Crossbar (`rtl/core/neorv32_memory_crossbar.vhd`)
* **Bandwidth:** 256-bit wide data bus between the systolic array and tensor memory.
* **Arbitration:** Non-blocking 2-master (CPU Wishbone + DMA), 1-slave crossbar arbiter with cycle-level round-robin priority.

### 3. VGA Raster Controller (`rtl/core/neorv32_vga.vhd`)
* **Resolution Support:**
  * Native $160 \times 120$ @ 8bpp with 4x hardware upscaler to $640 \times 480$ @ 60 Hz (19,200 bytes dual-port VRAM).
  * Native $320 \times 200$ @ 4bpp packed-nibble raster mode (32,000 bytes dual-port VRAM).
* **Color Output:** 256-entry $\times$ 12-bit RGB Color Lookup Table (CLUT) mapping indices directly to 12-bit DAC outputs (4-bit R, 4-bit G, 4-bit B).

### 4. Debounced PS/2 Keyboard Receiver (`rtl/core/neorv32_ps2.vhd`)
* **Digital Filtering:** Synchronous 100 kHz deglitching filter rejecting contact bounce and line noise.
* **Frame Decoder:** 11-bit serial frame parser (Start bit, 8 data bits, Odd Parity, Stop bit).
* **Buffer:** 16-byte circular FIFO with status and overflow indicators.

---

## Simulation & IP Packaging

### Running Simulation (GHDL)
```bash
ghdl -a --std=08 rtl/core/*.vhd sim/neorv32_tb.vhd
ghdl -e --std=08 neorv32_tb
ghdl -r --std=08 neorv32_tb --stop-time=10ms --vcd=wave.vcd
```

### Packaging as Vivado IP Block
To package GEMMrv32 into a Vivado IP-XACT catalog block:
```bash
vivado -mode batch -source rtl/system_integration/neorv32_vivado_ip.tcl
```

---

## Technical Documentation Pointers

* **Master Hardware Specification:** [`docs/GEMMRV32_SYSTEM_SPECIFICATION.md`](docs/GEMMRV32_SYSTEM_SPECIFICATION.md)
  * Section 2: Address Space & Memory Mapping Architecture
  * Section 3: Hardware Peripheral & Coprocessor VHDL Specifications
  * Section 6.1: The 32-bit vs 8-bit VRAM Write Anomaly & Resolution

---

## Repository Branch Directory

* [`master`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/master): Main index and baseline repository snapshot.
* [`pure-rtl`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/pure-rtl): **(You are here)** Board-agnostic VHDL core IP library.
* [`nexys`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/nexys): Digilent Nexys A7 100T TinyML platform with TensorFlow Lite Micro & LeNet.
* [`basys`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/basys): Clean Basys 3 SoC baseline with tracked bitstream and pure TCL flow.
* [`basys-doom`](https://github.com/JeromeAntonyRobin/GEMMPrivate/tree/basys-doom): Complete 3D DOOM gaming platform.
