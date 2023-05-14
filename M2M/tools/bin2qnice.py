#!/usr/bin/env python3

import sys
import os

def binary_to_hexdump(binary_file, hexdump_file, offset=0, chunk_size=None):
    chunk_counter = 1
    with open(binary_file, 'rb') as bin_file:
        while True:
            hexdump_file_chunk = f"{hexdump_file}.{chunk_counter}"
            with open(hexdump_file_chunk, 'w') as hex_file:
                address = offset
                empty_chunk = True
                for _ in range(chunk_size) if chunk_size else iter(int, 1):
                    byte = bin_file.read(1)
                    if not byte:
                        break

                    empty_chunk = False
                    hex_byte = int.from_bytes(byte, byteorder='big')
                    hex_line = f"0x{address:04X} 0x{hex_byte:04X}\n"
                    hex_file.write(hex_line)
                    address += 1

            if empty_chunk:
                os.remove(hexdump_file_chunk)

            if not byte:
                break

            chunk_counter += 1

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 binary_to_hexdump.py <binary_file> <hexdump_file> [offset] [chunk_size]")
        sys.exit(1)

    binary_file = sys.argv[1]
    hexdump_file = sys.argv[2]
    offset = 0
    chunk_size = None

    if len(sys.argv) >= 4:
        try:
            offset = int(sys.argv[3], 16)
        except ValueError:
            print("Error: Invalid offset value. Please provide a hexadecimal value.")
            sys.exit(1)

    if len(sys.argv) == 5:
        try:
            chunk_size = int(sys.argv[4], 16)
        except ValueError:
            print("Error: Invalid chunk size value. Please provide a hexadecimal value.")
            sys.exit(1)

    binary_to_hexdump(binary_file, hexdump_file, offset, chunk_size)
