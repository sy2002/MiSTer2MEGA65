#!/usr/bin/env bash

if [ $# -ne 2 ]
then
  echo "Usage: bin2rom <binary input file> <32-bit ROM output file>"
  exit
fi

xxd -b -c 1 $1|cut -d ' ' -f 2 > $2
