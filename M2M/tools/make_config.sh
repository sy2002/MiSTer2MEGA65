#!/usr/bin/env bash

if [ $# -ne 2 ]; then
  echo "MiSTer2MEGA65 - Create empty config file. Usage: make_config.sh <filename> <OPTM_SIZE|auto>"
  exit
fi

if [ "$2" = "auto" ]; then
  OPTM_SIZE=$(grep "constant OPTM_SIZE" "../../CORE/vhdl/config.vhd" | sed -E 's/.*:= ([0-9]+).*/\1/')
  if [ -z "$OPTM_SIZE" ]; then
    echo "Error: Could not find OPTM_SIZE in ../../CORE/vhdl/config.vhd"
    exit 1
  fi
elif [[ "$2" =~ ^[0-9]+$ ]] && [[ $2 -ge 1 ]]; then
  OPTM_SIZE=$2
else
  echo "MiSTer2MEGA65 - Create empty config file. Usage: make_config.sh <filename> <OPTM_SIZE>"
  echo "Error: <OPTM_SIZE> needs to be an integer which is >= 1 or 'auto'"
  exit 1
fi

configfile=""

for (( i=1; i<= $OPTM_SIZE; i++ ))
do
    configfile="${configfile}\xff"
done

echo -ne "$configfile" > "$1"
