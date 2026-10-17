# GEMMrv32 Standard Neural Network Inference Demo

This project demonstrates edge neural network inference on the **GEMMrv32 RISC-V SoC** using the **CMSIS-NN / TFLite Micro compatible API** accelerated by the on-chip **$8 \times 8$ systolic array coprocessor (CFS)**.

---

## Architecture Overview

```
                      ┌─────────────────────────────────┐
                      │ Input Activations (int8, 32-dim)│
                      └────────────────┬────────────────┘
                                       │
                                       ▼
                      ┌─────────────────────────────────┐
                      │ Layer 1: Dense (32 -> 16, ReLU) │  <-- Hardware 8x8 Systolic Tiling
                      │    gemmrv_nn_dense_s8()         │
                      └────────────────┬────────────────┘
                                       │
                                       ▼
                      ┌─────────────────────────────────┐
                      │ Layer 2: Dense (16 -> 8, Linear)│  <-- Hardware 8x8 Systolic Tiling
                      │    gemmrv_nn_dense_s8()         │
                      └────────────────┬────────────────┘
                                       │
                                       ▼
                      ┌─────────────────────────────────┐
                      │ Classification: Argmax Output   │  <-- gemmrv_nn_argmax_s8()
                      └─────────────────────────────────┘
```

---

## Project Structure

* **`main.c`**: Inference pipeline initializing the hardware CFS coprocessor, streaming frames, computing cycles via RISC-V `CSR_MCYCLE`, and outputting logits & argmax over UART.
* **`model_weights.h`**: Auto-generated signed 8-bit quantized weights with 8-byte systolic stride padding and 4-byte pointer alignment generated via `gemm_quantizer.py`.
* **`Makefile`**: Auto-links `gemmrv_hw.c` and `gemmrv_nn.c` from `../gemm_lib`.

---

## How to Build & Run

### 1. Compile with GNU Make (Bundled or System RISC-V GCC)
```bash
make clean_all exe
```
This generates `neorv32_exe.bin`.

### 2. Upload to GEMMrv32 SoC via UART Bootloader
```bash
# Using GEMMrvStudio CLI or python serial uploader
python3 gemm_dashboard.py flash neorv32_exe.bin --port /dev/ttyUSB1 --console
```

### 3. Expected Live Serial Output (@ 19200 Baud)
```text
========================================
   GEMMrv32 SoC Neural Inference #10    
========================================
Input Feature[0]: -24
Output Logits:    [-128, -128, -128, 127, -128, -128, 127, 117]
Predicted Class:  3
Systolic Latency: 9656 CPU clock cycles
STATUS: SUCCESS
```
