#!/usr/bin/env python3
"""Convert raw binary to Verilog $readmemh format for a 64-bit wide BRAM.
Usage: python3 bin2hex.py firmware.bin > Debug/ram.hex
"""
import sys

with open(sys.argv[1], "rb") as f:
    data = f.read()

while len(data) % 8:
    data += b'\x00'

for i in range(0, len(data), 8):
    val = int.from_bytes(data[i:i+8], 'little')
    print(f'{val:016x}')
