#!/usr/bin/env bash

if [ ! -f ../../M2M/QNICE/assembler/qasm ]; then
    echo ""
    echo "ERROR: QNICE assembler ../../M2M/QNICE/assembler/qasm not found."
    echo ""
    echo "Things to try:"
    echo "1. This repository has dependencies: Did you run"
    echo "       git submodule update --init --recursive"
    echo "   after cloning the repository? If not, run it now."
    echo ""
    echo "2. Build the QNICE toolchain. Answer all questions by pressing ENTER."
    echo "       cd ../../M2M/QNICE/tools"
    echo "       ./make-toolchain.sh"
    echo ""
    exit
fi;

../../M2M/QNICE/assembler/asm m2m-rom.asm
