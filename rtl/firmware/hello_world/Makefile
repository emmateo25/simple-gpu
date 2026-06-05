#CROSS = riscv32-unknown-elf
# If the above is not found, try: riscv64-unknown-elf
CROSS = riscv64-unknown-elf

CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy

CFLAGS  = -march=rv32imc -mabi=ilp32 -O2 -Wall -nostdlib -nostartfiles
LDFLAGS = -T link.ld

TARGET  = firmware
SRCS    = crt0.S main.c
HEX_DIR = Debug

all: $(HEX_DIR)/ram.hex

$(TARGET).elf: $(SRCS) link.ld font8x8.h
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRCS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(HEX_DIR)/ram.hex: $(TARGET).bin
	mkdir -p $(HEX_DIR)
	python3 bin2hex.py $< > $@
	@echo "Generated $(HEX_DIR)/ram.hex"

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(HEX_DIR)/ram.hex

.PHONY: all clean
