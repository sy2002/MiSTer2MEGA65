#!/usr/bin/env bash
# MiSTer2MEGA65 vdrives regression test
#
# This framework is based on the MiSTer project.
# Powered by MiSTer2MEGA65.
# MiSTer2MEGA65 done by sy2002 and MJoergen since 2021 and licensed under GPL v3.

set -euo pipefail

test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "${test_dir}/../../.." && pwd)
test_workdir=$(mktemp -d "${TMPDIR:-/tmp}/m2m-vdrives-test.XXXXXX")

cleanup() {
   rm -rf -- "${test_workdir}"
}
trap cleanup EXIT

command -v ghdl >/dev/null 2>&1 || {
   echo "run_vdrives_test.sh: ghdl is required" >&2
   exit 1
}

mkdir -p "${test_workdir}/xpm" "${test_workdir}/work"

(
   cd -- "${test_workdir}"

   ghdl -a --std=08 --work=xpm --workdir="${test_workdir}/xpm" \
      "${test_dir}/xpm_cdc_array_single_stub.vhd"

   ghdl -a --std=08 -P"${test_workdir}/xpm" --workdir="${test_workdir}/work" \
      "${test_dir}/globals_stub.vhd" \
      "${repo_dir}/M2M/vhdl/vdrives.vhd" \
      "${test_dir}/vdrives_test.vhd"

   ghdl -e --std=08 -P"${test_workdir}/xpm" --workdir="${test_workdir}/work" \
      vdrives_legacy_port_test

   ghdl -e --std=08 -P"${test_workdir}/xpm" --workdir="${test_workdir}/work" \
      vdrives_test

   ghdl -r --std=08 -P"${test_workdir}/xpm" --workdir="${test_workdir}/work" \
      vdrives_test --assert-level=error
)

if command -v nvc >/dev/null 2>&1; then
   (
      cd -- "${test_workdir}"

      nvc --std=2008 --work=xpm:"${test_workdir}/nvc-xpm" --init
      nvc --std=2008 --work=work:"${test_workdir}/nvc-work" --init

      nvc --std=2008 --work=xpm:"${test_workdir}/nvc-xpm" -a \
         "${test_dir}/xpm_cdc_array_single_stub.vhd"

      nvc --std=2008 --work=work:"${test_workdir}/nvc-work" \
         --map=xpm:"${test_workdir}/nvc-xpm" -a \
         "${test_dir}/globals_stub.vhd" \
         "${repo_dir}/M2M/vhdl/vdrives.vhd" \
         "${test_dir}/vdrives_test.vhd"

      nvc --std=2008 --work=work:"${test_workdir}/nvc-work" \
         --map=xpm:"${test_workdir}/nvc-xpm" -e --no-save vdrives_legacy_port_test

      nvc --std=2008 --work=work:"${test_workdir}/nvc-work" \
         --map=xpm:"${test_workdir}/nvc-xpm" -e --no-save vdrives_test \
         -r vdrives_test --exit-severity=error
   )
fi
