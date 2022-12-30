#!/usr/bin/env bash

if [ $# -ne 2 ]; then
  echo "MiSTer2MEGA65 - Create empty config file. Usage: make_config.sh <filename> <OPTM_SIZE>"
  exit
fi

if [[ ! "$2" =~ ^[0-9]+$ ]] || [[ $2 -lt 1 ]]; then 
  echo "MiSTer2MEGA65 - Create empty config file. Usage: make_config.sh <filename> <OPTM_SIZE>"
  echo "Error: <OPTM_SIZE> needs to be an integer which is >= 1"
  exit 1
fi

configfile=""

for (( i=1; i<= $2; i++ ))
do
    configfile="${configfile}\xff"
done

echo -ne $configfile > $1
