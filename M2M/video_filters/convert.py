#!/usr/bin/env python3

import math

MODE_OUT = 1
MODE_ASM = 2

def tohex(val, nbits):
    return format((val + (1 << nbits)) % (1 << nbits), '04X')

def convert_file(mode, file_in, file_out, address, bits, skip_header_lines, skip_lines, shift_right, shift_left):
    with open(file_in, 'r') as input:
        with open(file_out, 'w') as output:
            element_counter = 0;    
            lines = input.readlines()

            if mode == MODE_ASM:
                for i in range (0, skip_header_lines):
                    output.write('; ' + lines[i])
                output.write((file_in[:len(file_in)-4]+'\n').upper())

            lines = lines[skip_header_lines:]
            skip_counter = 0

            for line in lines:
                elements = line.split(',')
                if len(elements) == 4:
                    if skip_counter % skip_lines == 0:
                        int_elements = list(map(int, elements))
                        if mode == MODE_OUT:
                            for e in int_elements:
                                output.write('0x' + tohex(address + element_counter, 16) + ' ')
                                output.write('0x' + tohex(math.floor(e / 2**shift_right) * 2**shift_left, bits) + '\n')
                                element_counter = element_counter + 1
                        else:
                            output.write('.DW ')
                            elm_in_line = 1
                            for e in int_elements:
                                output.write('0x' + tohex(math.floor(e / 2**shift_right) * 2**shift_left, bits))
                                if elm_in_line != 4:
                                    output.write(', ')
                                    elm_in_line = elm_in_line + 1
                                else:
                                    output.write('\n')
                                    
                    skip_counter = skip_counter + 1

convert_file(MODE_OUT, 'lanczos2_12.txt',     'lanczos2_12.out'    , 0x7000, 10, 6, 4, 0, 0)
convert_file(MODE_ASM, 'lanczos2_12.txt',     'lanczos2_12.asm'    , 0x7000, 10, 6, 4, 0, 0)
convert_file(MODE_OUT, 'Scanlines_80.txt',    'Scanlines_80.out'   , 0x7100, 10, 7, 1, 0, 1)
convert_file(MODE_ASM, 'Scanlines_80.txt',    'Scanlines_80.asm'   , 0x7100, 10, 7, 1, 0, 1)
convert_file(MODE_OUT, 'Scan_Br_105_80.txt',  'Scan_Br_105_80.out' , 0x7100, 10, 7, 1, 0, 1)
convert_file(MODE_ASM, 'Scan_Br_105_80.txt',  'Scan_Br_105_80.asm' , 0x7100, 10, 7, 1, 0, 1)
convert_file(MODE_OUT, 'Scan_Br_110_80.txt',  'Scan_Br_110_80.out' , 0x7100, 10, 7, 1, 0, 1)
convert_file(MODE_ASM, 'Scan_Br_110_80.txt',  'Scan_Br_110_80.asm' , 0x7100, 10, 7, 1, 0, 1)
convert_file(MODE_OUT, 'Scan_Br_115_80.txt',  'Scan_Br_115_80.out' , 0x7100, 10, 7, 1, 0, 1)
convert_file(MODE_ASM, 'Scan_Br_115_80.txt',  'Scan_Br_115_80.asm' , 0x7100, 10, 7, 1, 0, 1)
convert_file(MODE_OUT, 'Scan_Br_120_80.txt',  'Scan_Br_120_80.out' , 0x7100, 10, 7, 1, 0, 1)
convert_file(MODE_ASM, 'Scan_Br_120_80.txt',  'Scan_Br_120_80.asm' , 0x7100, 10, 7, 1, 0, 1)
