## MiSTer2MEGA65
##
## MEGA65 port done by MJoergen and sy2002 in 2023 and licensed under GPL v3
##
## M2M constraints common for all board variants.

################################
## TIMING CONSTRAINTS
################################

## System board clock (100 MHz)
create_clock -period 10.000 -name clk [get_ports {clk_i}]

## Name Autogenerated Clocks
create_generated_clock -name qnice_clk       [get_pins i_framework/i_clk_m2m/i_clk_qnice/CLKOUT0]
create_generated_clock -name hr_clk          [get_pins i_framework/i_clk_m2m/i_clk_qnice/CLKOUT1]
create_generated_clock -name hr_delay_refclk [get_pins i_framework/i_clk_m2m/i_clk_qnice/CLKOUT2]
create_generated_clock -name hr_clk_del      [get_pins i_framework/i_clk_m2m/i_clk_qnice/CLKOUT3]
create_generated_clock -name audio_clk       [get_pins i_framework/i_clk_m2m/i_clk_audio/CLKOUT0]
create_generated_clock -name tmds_clk        [get_pins i_framework/i_video_out_clock/MMCM/CLKOUT0]
create_generated_clock -name hdmi_clk        [get_pins i_framework/i_video_out_clock/MMCM/CLKOUT1]

## The following constraints are needed by M2M/vhdl/controllers/HDMI/video_out_clock.vhd
create_generated_clock -name div_clk -source [get_ports {clk_i}] -divide_by 2 [get_pins i_framework/i_video_out_clock/clki_div_reg/Q]
set_case_analysis 1 [get_pins i_framework/i_video_out_clock/clk_mux_reg/Q]

## The high level reset signals are slow enough so that we can afford a false path
set_false_path -from [get_pins i_framework/i_reset_manager/reset_m2m_n_o_reg/C]
set_false_path -from [get_pins i_framework/i_reset_manager/reset_core_n_o_reg/C]

## Generic CDC
set_max_delay 8 -datapath_only -from [get_generated_clocks] -to [get_pins -hierarchical "*cdc_stable_gen.dst_*_d_reg[*]/D"]
set_max_delay 8 -datapath_only -from [get_clocks clk] -to [get_pins -hierarchical "*cdc_stable_gen.dst_*_d_reg[*]/D"]


################################################################################
# HyperRAM
################################################################################

# HyperRAM output clock relative to delayed clock
create_generated_clock -name hr_ck -source [get_pins i_framework/i_clk_m2m/i_clk_qnice/CLKOUT3] -multiply_by 1 [get_ports hr_clk_p_o]

# HyperRAM RWDS as a clock for the read path (hr_dq -> IDDR -> CDC)
create_clock -period 10.000 -name hr_rwds -waveform {2.5 7.5} [get_ports hr_rwds_io]

# Asynchronous clocks
set_false_path -from [get_ports hr_rwds_io] -to [get_clocks hr_ck]

# HyperRAM timing (correct for IS66WVH8M8DBLL-100B1LI)
set HR_tIS   1.0 ; # input setup time
set HR_tIH   1.0 ; # input hold time
set tDSSmax  0.8 ; # RWDS to data valid, max
set tDSHmin -0.8 ; # RWDS to data invalid, min

# FPGA to HyperRAM (address and write data)
set_property IOB TRUE [get_cells i_framework/i_hyperram/hyperram_tx_inst/hr_rwds_oe_n_reg ]
set_property IOB TRUE [get_cells i_framework/i_hyperram/hyperram_tx_inst/hr_dq_oe_n_reg[*] ]
set_property IOB TRUE [get_cells i_framework/i_hyperram/hyperram_ctrl_inst/hb_csn_o_reg ]
set_property IOB TRUE [get_cells i_framework/i_hyperram/hyperram_ctrl_inst/hb_rstn_o_reg ]
# setup
set_output_delay -max  $HR_tIS -clock hr_ck [get_ports {hr_reset_o hr_cs0_o hr_rwds_io hr_d_io[*]}]
set_output_delay -max  $HR_tIS -clock hr_ck [get_ports {hr_reset_o hr_cs0_o hr_rwds_io hr_d_io[*]}] -clock_fall -add_delay
# hold
set_output_delay -min -$HR_tIH -clock hr_ck [get_ports {hr_reset_o hr_cs0_o hr_rwds_io hr_d_io[*]}]
set_output_delay -min -$HR_tIH -clock hr_ck [get_ports {hr_reset_o hr_cs0_o hr_rwds_io hr_d_io[*]}] -clock_fall -add_delay

# HyperRAM to FPGA (read data, clocked in by RWDS)
# edge aligned, so pretend that data is launched by previous edge
# setup
set_input_delay -max [expr 5.0+$tDSSmax] -clock hr_rwds [get_ports hr_d_io[*]]
set_input_delay -max [expr 5.0+$tDSSmax] -clock hr_rwds [get_ports hr_d_io[*]] -clock_fall -add_delay
# hold
set_input_delay -min [expr 5.0+$tDSHmin] -clock hr_rwds [get_ports hr_d_io[*]]
set_input_delay -min [expr 5.0+$tDSHmin] -clock hr_rwds [get_ports hr_d_io[*]] -clock_fall -add_delay
# Clock Domain Crossing
set_max_delay 2 -datapath_only -from [get_cells i_framework/i_hyperram/hyperram_ctrl_inst/hb_read_o_reg]
set_max_delay 2 -datapath_only -from [get_cells i_framework/i_hyperram/hyperram_rx_inst/iddr_dq_gen[*].iddr_dq_inst]
# Prevent insertion of extra BUFG
set_property CLOCK_BUFFER_TYPE NONE [get_nets -of [get_pins i_framework/i_hyperram/hyperram_rx_inst/delay_rwds_inst/DATAOUT]]


################################################################################
# QNICE
################################################################################

## QNICE's EAE combinatorial division networks take longer than the regular clock period, so we specify a multicycle path
## see also the comments in EAE.vhd and explanations in UG903/chapter 5/Multicycle Paths as well as ug911/page 25
set_multicycle_path -from [get_cells -include_replicated {i_framework/i_qnice_wrapper/QNICE_SOC/eae_inst/op*_reg[*]}] \
   -to [get_cells -include_replicated {i_framework/i_qnice_wrapper/QNICE_SOC/eae_inst/res_reg[*]}] -setup 3
set_multicycle_path -from [get_cells -include_replicated {i_framework/i_qnice_wrapper/QNICE_SOC/eae_inst/op*_reg[*]}] \
   -to [get_cells -include_replicated {i_framework/i_qnice_wrapper/QNICE_SOC/eae_inst/res_reg[*]}] -hold 2


################################################################################
# ASCAL
################################################################################

# Timing between the two system clocks, ascal.vhd, audio, HDMI and HyperRAM is asynchronous.
# The ascal operates with three different clock domains, and the signals are
# consistently named accordingly:
# i_*   : This is the input stream, i.e. the Core clock domain.
# o_*   : This is the output stream, i.e. the HDMI clock domain.
# avl_* : This is the video buffer, i.e. the HyperRAM clock domain.
# However, we can not refer directly to the Core clock domain here, so instead we make
# some indirect references.
set_false_path -quiet -from [get_pins -hierarchical -regexp ".*/i_ascal/i_.*_reg.*/C"]   -to [get_pins -hierarchical -regexp ".*/i_ascal/avl_.*_reg.*/D"]
set_false_path -quiet -from [get_pins -hierarchical -regexp ".*/i_ascal/i_.*_reg.*/C"]   -to [get_pins -hierarchical -regexp ".*/i_ascal/o_.*_reg.*/D"]
set_false_path -quiet -from [get_pins -hierarchical -regexp ".*/i_ascal/avl_.*_reg.*/C"] -to [get_pins -hierarchical -regexp ".*/i_ascal/o_.*_reg.*/D"]
set_false_path -quiet -from [get_pins -hierarchical -regexp ".*/i_ascal/o_.*_reg.*/C"]   -to [get_pins -hierarchical -regexp ".*/i_ascal/i_.*_reg.*/D"]
set_false_path -quiet -from [get_pins -hierarchical -regexp ".*/i_ascal/o_.*_reg.*/C"]   -to [get_pins -hierarchical -regexp ".*/i_ascal/avl_.*_reg.*/D"]

set_false_path -from [get_clocks hdmi_clk]  -to [get_clocks audio_clk]
set_false_path -from [get_clocks audio_clk] -to [get_clocks hdmi_clk]
set_false_path -from [get_clocks qnice_clk] -to [get_clocks hdmi_clk]
set_false_path -through [get_pins i_framework/i_av_pipeline/i_digital_pipeline/i_ascal/reset_na]


################################
## CONFIGURATION AND BITSTREAM PROPERTIES
################################

set_property CONFIG_VOLTAGE                  3.3   [current_design]
set_property CFGBVS                          VCCO  [current_design]
set_property BITSTREAM.GENERAL.COMPRESS      TRUE  [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE     66    [current_design]
set_property CONFIG_MODE                     SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES   [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH   4     [current_design]

