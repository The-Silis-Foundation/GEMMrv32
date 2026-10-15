# GEMMrv32 Nexys A7: Hardware-Accelerated TinyML SoC on Digilent Nexys A7

[![Target Platform](https://img.shields.io/badge/FPGA-Digilent%20Nexys%20A7%20(XC7A100T)-orange?style=flat-square)](https://digilent.com/reference/programmable-logic/nexys-a7/start)
[![ISA](https://img.shields.io/badge/ISA-RV32IM-green?style=flat-square)](https://riscv.org)
[![Inference Speedup](https://img.shields.io/badge/Speedup-14.7x%20End--to--End-brightgreen?style=flat-square)]()
[![Runtime](https://img.shields.io/badge/Runtime-TensorFlow%20Lite%20Micro-blue?style=flat-square)](https://www.tensorflow.org/lite/microcontrollers)
[![Author](https://img.shields.io/badge/Author-JeromeAntonyRobin-black?style=flat-square)](https://github.com/JeromeAntonyRobin)

GEMMrv32 is a hardware-accelerated bare-metal TinyML SoC built on the **NEORV32 RISC-V processor**. It extends the processor with a custom **8x8 systolic-array GEMM coprocessor**, a **256-bit wide DMA memory crossbar**, and a fully ported **TensorFlow Lite Micro (TFLM)** runtime — all executing without an operating system.

The system is verified on a **Digilent Nexys A7 FPGA (Artix-7 XC7A100T)** and achieves a **14.7x end-to-end neural network inference speedup** over software execution on the same processor.

---

## Branch Overview: `nexysa7`

This branch contains the **Edge AI & TinyML reference system**, including the bare-metal TensorFlow Lite Micro runtime tree, the LeNet 23-class color classifier demo, and cycle-accurate benchmarks.

```
+-----------------------------------------------------------------------------------+
|                        NEXYS A7 TinyML SYSTEM ARCHITECTURE                        |
|                                                                                   |
|   +---------------------------------------------------------------------------+   |
|   |                        NEORV32 RV32IM CPU @ 100 MHz                       |   |
|   |         Bare-Metal TensorFlow Lite Micro (TFLM) Execution Runtime         |   |
|   +---------------------------------------------------------------------------+   |
|          │                                                       │                |
|          │ CFS Coprocessor Port (0xFFEA0000)                     │ DMA Interface  |
|          ▼                                                       ▼                |
|   +---------------------------------------------------------------------------+   |
|   |                  256-bit Wide DMA Memory Crossbar                         |   |
|   +---------------------------------------------------------------------------+   |
|          │                                                       │                |
|          ▼                                                       ▼                |
|   +--------------------------+                         +----------------------+   |
|   |  8x8 Systolic GEMM Unit  |                         |  Dedicated 256-bit   |   |
|   |  - 64 MAC Operations/Clk |                         |  Tensor BRAM Buffer  |   |
|   |  - int8 Input / int32 Acc|                         |  (Zero CPU Stalling) |   |
|   +--------------------------+                         +----------------------+   |
+-----------------------------------------------------------------------------------+
```

---

## Key Hardware Additions

* **Custom 8x8 Systolic GEMM Accelerator (`rtl/core/neorv32_cfs.vhd`)**: Memory-mapped coprocessor via the NEORV32 Custom Functions Subsystem (CFS) interface at `0xFFEA0000`. Computes an $8 \times 8$ matrix multiplication in hardware with 64 parallel multiply-accumulate operations per clock cycle.
* **256-bit Wide DMA Crossbar (`rtl/core/neorv32_memory_crossbar.vhd`)**: High-bandwidth memory arbiter streaming packed tensor tiles between memory and systolic array registers.
* **Dedicated Tensor BRAM (`rtl/core/neorv32_wide_bram.vhd`)**: 256-bit wide data port Block RAM for high-throughput tensor storage.

---

## TensorFlow Lite Micro Port & Inference Pipeline

* **Standalone TFLM Runtime (`sw/example/tflm_tree/`)**: Complete self-contained TensorFlow Lite Micro runtime tree ported for bare-metal RV32IM execution without libc heap or POSIX OS dependencies.
* **LeNet Color Classifier Demo (`sw/example/demo_lenet/`)**: 
  * 23-class automotive color classification CNN.
  * Implements `im2col` activation tensor formatting.
  * Dynamically schedules convolutional layer matrix multiplications onto the 8x8 systolic GEMM coprocessor.
  * Performs dual execution (software GEMM vs hardware GEMM) to verify bit-exact numerical correctness.

---

## Performance Results

Measured live on FPGA hardware using RISC-V hardware performance counter CSRs (`mcycle`):

| Pipeline Stage | Pure Software (RV32IM) | Hardware Accelerated (GEMMrv32) | Speedup Factor |
|---|:---:|:---:|:---:|
| **Conv2D Layer 1** | 2,840,110 cycles | 192,400 cycles | **14.8x** |
| **Conv2D Layer 2** | 4,912,300 cycles | 334,150 cycles | **14.7x** |
| **Dense / FC Layer** | 310,400 cycles | 22,170 cycles | **14.0x** |
| **End-to-End Total** | **8,062,810 cycles** | **548,720 cycles** | **14.7x** |

---

## Included Firmware Demos

* **[`sw/example/demo_lenet/`](sw/example/demo_lenet/)**: Full 23-class color classification CNN inference pipeline with trained quantized int8 weights (`lenet_weights.h`).
* **[`sw/example/demo_gemm/`](sw/example/demo_gemm/)**: Standalone GEMM benchmark comparing randomized software vs hardware matrix multiplication cycles.
* **[`sw/example/demo_cnn_classifier/`](sw/example/demo_cnn_classifier/)**: Lightweight quantized CNN classifier.
* **[`sw/example/demo_micro_transformer/`](sw/example/demo_micro_transformer/)**: Minimal transformer model inference demonstration.

---

## Technical Documentation Pointers

* **Master Architecture Specification:** [`docs/GEMMRV32_SYSTEM_SPECIFICATION.md`](docs/GEMMRV32_SYSTEM_SPECIFICATION.md)
  * Section 3.3: 8x8 Systolic GEMM Coprocessor Architecture & CFS Register Map
  * Section 4: Hardware Coprocessor Drivers & C API
* **Bootloader & UART Timing Debug Report:** [`docs/HARDWARE_DEBUG_REPORT.md`](docs/HARDWARE_DEBUG_REPORT.md)

---

## Repository Branch Directory

* [`master`](https://github.com/The-Silis-Foundation/GEMMrv32/tree/master): Pure portable VHDL IP core library (NEORV32 + GEMM + DMA + VGA + PS/2).
* [`basys3`](https://github.com/The-Silis-Foundation/GEMMrv32/tree/basys3): Clean Basys 3 SoC baseline with tracked bitstream and pure TCL flow.
* [`nexysa7`](https://github.com/The-Silis-Foundation/GEMMrv32/tree/nexysa7): **(You are here)** Digilent Nexys A7 100T TinyML platform with TensorFlow Lite Micro & LeNet.

> [!NOTE]
> The standalone bare-metal 3D DOOM workstation is available in [**DOOM-on-GEMMrv32**](https://github.com/JeromeAntonyRobin/DOOM-on-GEMMrv32).
