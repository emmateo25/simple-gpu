CROSS   = riscv64-unknown-elf
CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy

CFLAGS  = -march=rv32imc -mabi=ilp32 -O2 -Wall -nostdlib -nostartfiles
LDFLAGS = -T link.ld

TARGET  = firmware
SRCS    = crt0.S main.c

all: Debug/ram.hex

$(TARGET).elf: $(SRCS) link.ld font8x8.h
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRCS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

Debug/ram.hex: $(TARGET).bin
	mkdir -p Debug
	python3 bin2hex.py $< > $@
	@echo "Done: Debug/ram.hex"

clean:
	rm -f $(TARGET).elf $(TARGET).bin Debug/ram.hex

.PHONY: all clean
