# ==============================================================================
# GEMMrv32: Top-Level Makefile for Basys 3 (Open-Source Workflow)
# ==============================================================================

RISCV_PREFIX   ?= riscv64-unknown-elf-
OPENFPGALOADER ?= openFPGALoader
PYTHON         ?= python3
SERIAL_PORT    ?= /dev/ttyUSB1
BAUD           ?= 19200

BITSTREAM      := sw/basys/build/neorv32_basys3.bit
FLASH_BIN      := sw/basys/build/neorv32_basys3.bin

.PHONY: all examples clean clean_all flash-bit flash-spi upload help

all: help

examples:
	@echo "=== Building all software examples ==="
	$(MAKE) -C sw/example all RISCV_PREFIX=$(RISCV_PREFIX)

clean:
	$(MAKE) -C sw/example clean RISCV_PREFIX=$(RISCV_PREFIX)

clean_all:
	$(MAKE) -C sw/example clean_all RISCV_PREFIX=$(RISCV_PREFIX)

flash-bit:
	@echo "=== Flashing Basys 3 FPGA Bitstream (SRAM / JTAG via openFPGALoader) ==="
	$(OPENFPGALOADER) --board=basys3 $(BITSTREAM)

flash-spi:
	@echo "=== Flashing Basys 3 Non-Volatile SPI Flash via openFPGALoader ==="
	$(OPENFPGALOADER) --board=basys3 -f $(FLASH_BIN)

upload:
	@if [ -z "$(BIN)" ]; then \
		echo "Usage: make upload BIN=<path/to/neorv32_exe.bin>"; \
		exit 1; \
	fi
	@echo "=== Uploading $(BIN) to Basys 3 via UART loader ==="
	$(PYTHON) sw/basys/upload_firmware.py $(BIN) --port $(SERIAL_PORT) --baud $(BAUD)

help:
	@echo "GEMMrv32 Basys 3 Open-Source Workflow"
	@echo "-------------------------------------"
	@echo "  make flash-bit           - Program FPGA bitstream to Basys 3 (openFPGALoader)"
	@echo "  make flash-spi           - Program bitstream to onboard SPI Flash (openFPGALoader)"
	@echo "  make examples            - Build all bare-metal software examples"
	@echo "  make upload BIN=<path>   - Upload binary via UART bootloader"
	@echo "                             (e.g.: make upload BIN=sw/example/demo_blink_led/neorv32_exe.bin)"
	@echo "  make clean               - Clean compiled software artifacts"
