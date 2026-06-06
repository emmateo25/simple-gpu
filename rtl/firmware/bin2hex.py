#!/usr/bin/env python3
"""
Convert a flat binary to $readmemh hex format for the E203 ITCM (64-bit wide BRAM).

Each output line = 16 hex digits = one 64-bit BRAM word.

Byte ordering inside each word:
  - RISC-V is little-endian: the byte at the LOWEST address occupies bits[7:0].
  - $readmemh reads the leftmost hex digit as the MOST-SIGNIFICANT bits.
  - Therefore: line = hex(byte7 byte6 byte5 byte4 byte3 byte2 byte1 byte0)
               i.e.  struct.unpack('<Q', 8_bytes)[0] formatted as 16 hex chars.

E203 ITCM parameters (from config.v):
  E203_CFG_ITCM_ADDR_WIDTH = 14  →  depth = 2^(14-3) = 2048 words = 16384 bytes
"""
import struct
import sys

ITCM_DEPTH = 2048   # 2^(14-3) 64-bit words for E203_CFG_ITCM_ADDR_WIDTH=14
ITCM_BYTES = ITCM_DEPTH * 8   # 16384 bytes


def convert(bin_path, hex_path):
    with open(bin_path, 'rb') as f:
        data = bytearray(f.read())

    if len(data) > ITCM_BYTES:
        print(f"ERROR: firmware is {len(data)} bytes, exceeds ITCM size of {ITCM_BYTES} bytes.")
        sys.exit(1)

    # Pad to a multiple of 8 bytes
    while len(data) % 8:
        data.append(0)

    with open(hex_path, 'w') as f:
        words = len(data) // 8
        for i in range(words):
            chunk = bytes(data[i*8 : i*8+8])
            val = struct.unpack('<Q', chunk)[0]   # little-endian 64-bit integer
            f.write(f'{val:016x}\n')
        # Fill the rest of ITCM with zeros
        for _ in range(words, ITCM_DEPTH):
            f.write('0000000000000000\n')

    print(f"OK: {len(data)} bytes → {hex_path}  ({words} of {ITCM_DEPTH} words used)")


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} firmware.bin output.hex")
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
