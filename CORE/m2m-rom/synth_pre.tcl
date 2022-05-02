set cur_dir [exec pwd]
# ../../CORE/CORE-R3.runs/synth_1/

cd ../../../CORE/m2m-rom/
exec ./make_rom.sh <@stdin >@stdout 2>@stderr
cd $cur_dir

