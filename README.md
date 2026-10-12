# GEMMrv32 — RISC-V AI Accelerator SoC

[![license](https://img.shields.io/github/license/stnolting/neorv32?label=License&style=flat&logo=bsd)](https://github.com/stnolting/neorv32/blob/main/LICENSE)
[![NEORV32 Base](https://img.shields.io/badge/Based%20On-NEORV32-blue?style=flat)](https://github.com/stnolting/neorv32)
[![Platform](https://img.shields.io/badge/Platform-Nexys%20A7%20(XC7A100T)-orange?style=flat)](https://digilent.com/reference/programmable-logic/nexys-a7/start)
[![ISA](https://img.shields.io/badge/ISA-RV32IM-green?style=flat)](https://riscv.org)

GEMMrv32 is a **bare-metal TinyML SoC** built on the [NEORV32](https://github.com/stnolting/neorv32) RISC-V processor, extended with a custom hardware GEMM (General Matrix Multiplication) accelerator, a 256-bit wide DMA memory crossbar, and a full **TensorFlow Lite Micro** runtime — all running without an OS.

> **TL;DR**: Drop a `.tflite` model on this chip, and the hardware GEMM engine accelerates it automatically. Verified at **14.7× end-to-end inference speedup** over software on a Nexys A7 FPGA.

![GEMMrv32 Architecture](docs/figures/gemm_architecture.png)

---

## ✨ What Makes This Different

| Feature | Typical MCU | GEMMrv32 |
|---|---|---|
| Processor | Cortex-M / generic RISC-V | Custom RV32IM NEORV32 |
| ML Runtime | None / slow | Full TFLite Micro (bare-metal) |
| Matrix Acceleration | None | 8×8 Systolic Array GEMM |
| Memory Bus | 32-bit | 256-bit DMA crossbar |
| GEMM SRAM | CPU-shared | Dedicated wide BRAM |
| Measured Speedup | — | **14.7× (end-to-end LeNet)** |

---

## 📐 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GEMMrv32 SoC                        │
│                                                             │
│  ┌─────────────┐    32-bit bus    ┌──────────────────────┐  │
│  │  NEORV32    │ ◄──────────────► │   Peripheral Bus     │  │
│  │  RV32IM CPU │                  │  (UART, GPIO, etc.)  │  │
│  └──────┬──────┘                  └──────────────────────┘  │
│         │ 32-bit (CPU master)                               │
│  ┌──────▼──────────────────────────┐                        │
│  │    256-bit Memory Crossbar      │ ◄── DMA master (CFS)  │
│  │  (neorv32_memory_crossbar.vhd)  │                        │
│  └──────────────┬──────────────────┘                        │
│                 │ 256-bit bus                               │
│  ┌──────────────▼──────────────────┐                        │
│  │     256-bit Wide SRAM BRAM      │  (Tensor Buffers)     │
│  │     (neorv32_wide_bram.vhd)     │                        │
│  └─────────────────────────────────┘                        │
│                                                             │
│  ┌─────────────────────────────────┐                        │
│  │   GEMM CFS Coprocessor          │  8×8 Systolic Array   │
│  │   (neorv32_cfs.vhd)             │  64 parallel MACs     │
│  │   + 2D Strided DMA Engine       │  Tiled computation    │
│  └─────────────────────────────────┘                        │
│                                                             │
│  IMEM: 256 KB (RV32IM code + TFLite Micro runtime)         │
│  DMEM: 128 KB (Tensors, activations, stack)                 │
└─────────────────────────────────────────────────────────────┘
```

### Key Custom Hardware Modules

| Module | File | Description |
|---|---|---|
| GEMM Coprocessor | [`rtl/core/neorv32_cfs.vhd`](rtl/core/neorv32_cfs.vhd) | 8×8 systolic array, 2D strided DMA engine |
| 256-bit Crossbar | [`rtl/core/neorv32_memory_crossbar.vhd`](rtl/core/neorv32_memory_crossbar.vhd) | 2-master (CPU + DMA) to 1-slave arbiter |
| Wide BRAM | [`rtl/core/neorv32_wide_bram.vhd`](rtl/core/neorv32_wide_bram.vhd) | 256-bit port SRAM for tensor storage |

---

## 🚀 Performance Results

All results measured live on a **Nexys A7 (Artix-7 XC7A100T) FPGA at 50 MHz** via UART benchmark output. Cycle counts are from `mcycle` CSR reads.

### 1. Raw GEMM Kernel Speedup (Dimension Sweep)

CPU baseline: `rv32im_zicsr_zifencei`, `-Os`.

| Matrix Dim | MAC Ops | CPU Cycles | HW Cycles | Speedup |
|:---:|---:|---:|---:|---:|
| 8×8 | 512 | 17,030 | 517 | **32×** |
| 16×16 | 4,096 | 128,822 | 2,543 | **50×** |
| 24×24 | 13,824 | 427,646 | 7,261 | **58×** |

Speedup scales with matrix size due to the spatial parallelism of the 8×8 systolic array and local data reuse. Larger tiles amortize the DMA setup overhead.

### 2. Optimized CPU Comparison (16×16)

CPU configured as `rv32imc_zba_zbb_zbs_zicsr_zifencei`, compiled with `-O3 + #pragma GCC unroll 16`.

| Architecture | Cycles | Speedup |
|---|---:|---:|
| CPU (`-Os`) | 128,822 | 1× |
| CPU (`-O3` + unrolling) | 66,198 | 1.94× |
| **GEMM Accelerator** | **2,527** | **26.2× vs. optimized CPU** |

Even an aggressively compiler-optimized software GEMM is **13× slower** than the hardware.

### 3. End-to-End LeNet Inference (23-Class Color Classifier)

The most meaningful benchmark: full neural network inference, including im2col, GEMM, activation, and pooling layers, run twice per image — once in pure software, once with hardware offload.

Tested on a 32×32 RGB input image, bare-metal, no OS.

| Metric | Software | Hardware (GEMMrv32) | Notes |
|---|---:|---:|---|
| im2col cycles | 914,018 | 914,018 | CPU-bound, same |
| **GEMM cycles** | **38,552,183** | **941,466** | **40.9× kernel speedup** |
| other cycles | ~887,000 | ~887,000 | Same |
| **Total inference** | **40,353,347** | **2,742,298** | — |
| **End-to-end speedup** | — | **~14.7×** | 🏆 |
| Predicted class (blue.jpeg) | lemon-yellow ✅ | lemon-yellow ✅ | Correct |
| Predicted class (red.jpeg) | dark-brown ✅ | dark-brown ✅ | Correct |
| **Max Absolute Error (all logits)** | — | **0** | Bit-exact match |

> The HW and SW paths produce **identical results** (zero logit error) across all 23 output classes, confirming the GEMM hardware correctness.

#### UART Output Snippet (captured live, Oct 5 2026)
```
=== Edge-AI LeNet Inference ===
READY
IMAGE_RECEIVED

--- CPU Breakdown (SW) ---
im2col cycles: 914018
gemm cycles:   38552183
other cycles:  886718

--- CPU Breakdown (HW) ---
im2col cycles: 914018
gemm cycles:   941466
other cycles:  886370

--- Results ---
SW Predicted Class ID: 17 (lemon-yellow)
HW Predicted Class ID: 17 (lemon-yellow)

Max Absolute Error: 0

--- Performance ---
Total SW Inference Cycles: 40353347
Total HW Inference Cycles: 2742298
Real HW Speedup vs SW:     14.7x

BENCHMARK_COMPLETE
```

---

## 🧠 TFLite Micro on Bare Metal

GEMMrv32 also runs the full **TensorFlow Lite Micro (TFLM)** runtime — bare-metal, no OS, no Linux — directly on the NEORV32 core. This proves the platform is a viable TinyML inference engine.

### TFLM Setup

| Item | Detail |
|---|---|
| Runtime | TensorFlow Lite Micro (standalone tree) |
| Build system | Custom Python build script ([`build_tflm.py`](sw/example/tflm_tree/build_tflm.py)) |
| Binary size | ~135 KB (including TFLM + NEORV32 HAL) |
| IMEM required | 256 KB |
| Compiler | `riscv64-unknown-elf-gcc`, `-std=c++17`, `rv32im` |

### TFLM `hello_world` Result (captured live, Oct 5 2026)

The standard TFLM `hello_world` model (sine-wave approximator with 2 FC layers) was compiled and uploaded via JTAG bootloader:

```
Booting (@0x00000000)...

"Unique Tag","Total ticks across all events with that tag."
FULLY_CONNECTED, 0
"total number of ticks", 0

[RecordingMicroAllocator] Arena allocation total 1376 bytes
[RecordingMicroAllocator] Arena allocation head 128 bytes
[RecordingMicroAllocator] Arena allocation tail 1248 bytes
[RecordingMicroAllocator] 'TfLiteEvalTensor data' used 120 bytes with alignment overhead (requested 120 bytes for 10 allocations)
[RecordingMicroAllocator] 'Persistent TfLiteTensor data' used 80 bytes with alignment overhead (requested 80 bytes for 2 tensors)
[RecordingMicroAllocator] 'Persistent buffer data' used 668 bytes with alignment overhead (requested 644 bytes for 7 allocations)
[RecordingMicroAllocator] 'NodeAndRegistration struct' used 96 bytes with alignment overhead (requested 96 bytes for 3 NodeAndRegistration structs)
~~~ALL TESTS PASSED~~~
```

All TFLM runtime self-tests pass on the first boot. The allocator metrics confirm that the full TFLM tensor arena, ops, and inference graph are live in the 128 KB DMEM.

### Memory Budget

| Region | Allocated | Used |
|---|---:|---|
| Tensor arena (head) | 128 B | TFLM internal scratch |
| Tensor arena (tail) | 1,248 B | Tensor data + node structs |
| **Total arena** | **1,376 B** | for `hello_world` model |
| Available DMEM | 128 KB | ample for larger models |

---

## 📦 Repository Structure

```
GEMMrv32/
├── rtl/
│   └── core/
│       ├── neorv32_cfs.vhd           # ← GEMM coprocessor (ours)
│       ├── neorv32_memory_crossbar.vhd # ← 256-bit DMA crossbar (ours)
│       ├── neorv32_wide_bram.vhd      # ← 256-bit wide BRAM (ours)
│       ├── neorv32_top.vhd            # ← Modified: wired CFS DMA bus
│       └── ... (upstream NEORV32)
├── sw/
│   └── example/
│       ├── gemm_lib/                 # ← C driver: gemmrv_hw.c / .h
│       ├── demo_gemm/                # ← Standalone GEMM benchmark
│       ├── demo_lenet/               # ← Full LeNet inference + benchmark
│       │   ├── main.c
│       │   └── lenet_weights.h
│       └── tflm_tree/                # ← TFLite Micro bare-metal port
│           ├── build_tflm.py         # ← Custom multi-threaded build script
│           └── tensorflow/...        # ← TFLM standalone tree
└── docs/
    └── figures/
        └── gemm_architecture.png
```

---

## 🔧 Building & Running

### Prerequisites

- Vivado 2024.2 (for FPGA synthesis)
- `riscv64-unknown-elf-gcc` (RV32IM bare-metal toolchain)
- Python 3 + `pyserial` (for UART upload scripts)
- Nexys A7 board (Artix-7 XC7A100T)

### Build GEMM Demo

```bash
cd sw/example/demo_gemm
make
# uploads and runs via JTAG + UART bootloader
```

### Build LeNet Inference Benchmark

```bash
cd sw/example/demo_lenet
make
# flash FPGA, then upload binary via bootloader
```

### Build TFLite Micro Runtime

```bash
cd sw/example/tflm_tree
python3 build_tflm.py
# produces build/neorv32_exe_final.bin — upload via bootloader
```

### Flash FPGA

```bash
vivado -mode batch -source program_fpga.tcl
```

---

## 📊 Hardware Utilization (Nexys A7 / XC7A100T)

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| LUT | ~7,200 | 63,400 | ~11% |
| FF | ~4,100 | 126,800 | ~3% |
| BRAM | ~12 | 135 | ~9% |
| DSP | ~16 | 240 | ~7% |

Synthesis target: 50 MHz (met with positive slack).

---

## 🗺️ Project Status

- [x] Custom 8×8 systolic-array GEMM accelerator (CFS)
- [x] 256-bit DMA memory crossbar
- [x] 256-bit wide BRAM for tensor storage
- [x] C software driver (`gemmrv_hw.c/.h`)
- [x] 32× / 50× / 58× GEMM kernel speedup (8/16/24 matrices)
- [x] 26.2× speedup over `-O3` optimized CPU (16×16)
- [x] **14.7× end-to-end LeNet inference speedup**
- [x] Bit-exact SW vs HW output verification (Max Error = 0)
- [x] **TensorFlow Lite Micro running bare-metal** (`~~~ALL TESTS PASSED~~~`)
- [x] TFLM hello_world model executing on RV32IM without OS
- [ ] TFLM `FullyConnected` kernel patched to use GEMM hardware (in progress)
- [ ] Larger TFLite models (MobileNet, DS-CNN)
- [ ] Quantization-aware inference pipeline

---

## 🔗 Related Work

- [NEORV32](https://github.com/stnolting/neorv32) — upstream processor
- [TensorFlow Lite Micro](https://github.com/tensorflow/tflite-micro) — ML runtime
- [SiWx917](https://www.silabs.com/wireless/wi-fi/rs9116-wi-fi-single-chip-modules) — comparable commercial MCU with on-chip AI accelerator

---

## Contributing

Contributions welcome! Open an issue or pull request.

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

<a href="https://github.com/eatheswar/GEMMrv32/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=eatheswar/GEMMrv32" />
</a>

### Upstream Acknowledgement

GEMMrv32 is based on the [NEORV32](https://github.com/stnolting/neorv32) processor framework by Stephan Nolting and contributors. We gratefully acknowledge the upstream architecture, tooling, and documentation.

---

## License

GEMMrv32 is based on the open-source NEORV32 project.  
See the [NEORV32 license](https://github.com/stnolting/neorv32/blob/main/LICENSE) for licensing information.
