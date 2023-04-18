#!/usr/bin/env python3

# This script can be used to examine strings on the OPTM_HEAP for debugging
# and development purposes. Make sure that you define the constant OPTM_DX
# exactly as you have defined it in config.vhd
#
# Spaces are shown as °
# Zeros as *
# Ones as #
# Twos as ß
#
# Constraint: For some reason, pasting large amounts of dumps leads to
# omitted characters. So cut your dumps into chunks of 16 M/D output lines
# which are known to work.
#
# by sy2002 in April 2023

OPTM_DX = 25

import sys

WIDTH = OPTM_DX + 2

def process_hexdump_line(line):
    hex_values = line.split()[1:]  # Ignore the address part
    low_bytes = [hv[2:] for hv in hex_values]  # Extract the low bytes
    return ''.join(low_bytes)

def hex_to_ascii(hex_str):
    ascii_str = ''
    for i in range(0, len(hex_str), 2):
        hex_byte = hex_str[i:i+2]
        char = chr(int(hex_byte, 16))
        if char == chr(0):
            char = '*'
        elif char == chr(1):
            char = '#'
        elif char == chr(2):
            char = 'ß'
        elif char == ' ':
            char = '°'
        ascii_str += char
    return ascii_str

def main():
    hexdump = []
    print("Paste the M/D dump of OPTM_HEAP here. To finish, enter an empty line.")
    print("Make sure you are not dumping more than 16 lines at a time.")
    while True:
        line = input()
        if not line:
            break
        hexdump.append(line)

    processed_lines = [process_hexdump_line(line) for line in hexdump]
    hex_str = ''.join(processed_lines)
    ascii_str = hex_to_ascii(hex_str)

    # Output the ASCII string with a linebreak every WIDTH characters
    for i in range(0, len(ascii_str), WIDTH):
        ascii_line = ascii_str[i:i+WIDTH]
        hex_line = hex_str[i*2:i*2+WIDTH*2]  # Multiply by 2 to account for 2 hex chars per byte
        padded_ascii_line = ascii_line.ljust(WIDTH)
        sys.stdout.write(padded_ascii_line + ' ' * 8 + hex_line + '\n')

if __name__ == "__main__":
    main()
