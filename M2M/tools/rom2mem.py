#! /usr/bin/env python

# This converts a .rom file into a .mem file written in hexadecimal with each
# word on a single line.
# This is used to initialize memory.
#
# Usage: ./rom2mem.py <rom-file> <mem-file>

import sys

infilename = sys.argv[1]
outfilename = sys.argv[2]

result = ['@0000']

a = open(infilename, "r")
for line in a:
    v = int(line, 2)
    h = format(v, '04x')
    result.append(h)
a.close()

fl = open(outfilename, "w")
for i in result:
    fl.write(i+"\n")
fl.close()

