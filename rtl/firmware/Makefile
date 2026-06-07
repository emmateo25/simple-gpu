# ============================================================
# Firmware build for E203 RISC-V bare-metal (Tang Primer 20k)
# ============================================================
#
# Prerequisites (Ubuntu/Debian):
#   sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
#
# Usage:
#   make          → builds hello_world/Debug/ram.hex (ready for $readmemh)
#   make dis      → builds a disassembly listing for inspection
#   make clean    → removes all build outputs
# ============================================================

CROSS   := riscv64-unknown-elf
CC      := $(CROSS)-gcc
OBJCOPY := $(CROSS)-objcopy
OBJDUMP := $(CROSS)-objdump

# RV32IMC: base integer + multiply + compressed instructions
# -O0: no optimisation — safe with the const-cast in font8x8.h
CFLAGS  := -march=rv32imc -mabi=ilp32 -O0 -nostdlib \
           -ffunction-sections -fdata-sections \
           -Wall -Wno-unused-function

LDFLAGS := -T link.ld -Wl,--gc-sections

OUT     := hello_world/Debug
ELF     := $(OUT)/firmware.elf
BIN     := $(OUT)/firmware.bin
HEX     := $(OUT)/ram.hex
DIS     := $(OUT)/firmware.dis

SRCS    := crt0.S main.c

.PHONY: all dis clean

all: $(HEX)

$(OUT):
	mkdir -p $(OUT)

$(ELF): $(SRCS) link.ld font8x8.h | $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.S main.c -o $@
	@echo "Linked: $@"
	@$(CROSS)-size $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(HEX): $(BIN)
	python3 bin2hex.py $< $@

dis: $(ELF)
	$(OBJDUMP) -d -S $(ELF) > $(DIS)
	@echo "Disassembly: $(DIS)"

clean:
	rm -rf $(OUT)
