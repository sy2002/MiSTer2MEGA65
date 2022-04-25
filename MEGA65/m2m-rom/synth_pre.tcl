set cur_dir [exec pwd]
# ../../MEGA65/MEGA65-R3.runs/synth_1/

cd ../../../MEGA65/m2m-rom/
exec ./make_rom.sh <@stdin >@stdout 2>@stderr
cd $cur_dir

