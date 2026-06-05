#!/usr/bin/env python3
"""Convert a raw binary to Verilog $readmemh format for a 64-bit wide BRAM.

Usage:  python3 bin2hex.py firmware.bin > Debug/ram.hex

Each output line is one 64-bit word in little-endian byte order
(byte at lowest address in bits [7:0]) as 16 hex digits.
This matches how the E203 ITCM reads RISC-V instructions.
"""
import sys

with open(sys.argv[1], "rb") as f:
    data = f.read()

# Pad to 8-byte boundary
while len(data) % 8:
    data += b'\x00'

for i in range(0, len(data), 8):
    chunk = data[i:i+8]
    val = int.from_bytes(chunk, 'little')
    print(f'{val:016x}')
