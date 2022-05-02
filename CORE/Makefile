help:
	@echo "Available make targets are:"
	@echo "bit    : Generate the .bit and .mmi files."
	@echo "update : Update the .bit file with a new QNICE ROM."
	@echo "clean  : Remove all generated files."

# Specify install location of the Xilinx Vivado tool
XILINX_DIR = /opt/Xilinx/Vivado/2019.2

# Specify location of the QNICE ROM
ROM=QNICE/osm_rom.rom

# Specify the board revision - used as project name
BOARD=CORE-R3

# Specfy the top-level entity name
TOP=CORE_R3

# Specify source files
PPRDIR=.
VHDL2008=\
	$(PPRDIR)/../QNICE/vhdl/alu.vhd \
	$(PPRDIR)/vhdl/debouncer.vhd \
	$(PPRDIR)/vhdl/lcd_to_pixels.vhd \
	$(PPRDIR)/vhdl/video/vga_osm.vhd \
	$(PPRDIR)/vhdl/video/vga_core.vhd \
	$(PPRDIR)/vhdl/video/vga.vhd \
	$(PPRDIR)/vhdl/main.vhd \
	$(PPRDIR)/vhdl/mega65.vhd \
	$(PPRDIR)/vhdl/qnice.vhd \
	$(PPRDIR)/vhdl/top_mega65-r3.vhd

VHDL=\
	$(PPRDIR)/../QNICE/vhdl/alu_shifter.vhd \
	$(PPRDIR)/../QNICE/vhdl/basic_uart.vhd \
	$(PPRDIR)/../QNICE/vhdl/block_ram.vhd \
	$(PPRDIR)/../QNICE/vhdl/bus_uart.vhd \
	$(PPRDIR)/../QNICE/vhdl/byte_bram.vhd \
	$(PPRDIR)/../QNICE/vhdl/cpu_constants.vhd \
	$(PPRDIR)/../QNICE/vhdl/EAE.vhd \
	$(PPRDIR)/../QNICE/vhdl/fifo.vhd \
	$(PPRDIR)/../QNICE/vhdl/kbd_constants.vhd \
	$(PPRDIR)/../QNICE/vhdl/qnice_cpu.vhd \
	$(PPRDIR)/../QNICE/vhdl/register_file.vhd \
	$(PPRDIR)/../QNICE/vhdl/sdcard.vhd \
	$(PPRDIR)/../QNICE/vhdl/sd_spi.vhd \
	$(PPRDIR)/../QNICE/vhdl/tools.vhd \
	$(PPRDIR)/../rtl/boot_rom.vhd \
	$(PPRDIR)/../rtl/bus_savestates.vhd \
	$(PPRDIR)/../rtl/gbc_snd.vhd \
	$(PPRDIR)/../rtl/gb_savestates.vhd \
	$(PPRDIR)/../rtl/gb_statemanager.vhd \
	$(PPRDIR)/../rtl/reg_savestates.vhd \
	$(PPRDIR)/../rtl/speedcontrol.vhd \
	$(PPRDIR)/../rtl/T80/GBse.vhd \
	$(PPRDIR)/../rtl/T80/T80_ALU.vhd \
	$(PPRDIR)/../rtl/T80/T80_MCode.vhd \
	$(PPRDIR)/../rtl/T80/T80_Pack.vhd \
	$(PPRDIR)/../rtl/T80/T80_Reg.vhd \
	$(PPRDIR)/../rtl/T80/T80.vhd \
	$(PPRDIR)/vhdl/2port2clk_ram.vhd \
	$(PPRDIR)/vhdl/block_rom.vhd \
	$(PPRDIR)/vhdl/clk.vhd \
	$(PPRDIR)/vhdl/debounce.vhd \
	$(PPRDIR)/vhdl/controllers/kb_matrix_ram.vhdl \
	$(PPRDIR)/vhdl/controllers/matrix_to_keynum.vhdl \
	$(PPRDIR)/vhdl/controllers/mega65kbd_to_matrix.vhdl \
	$(PPRDIR)/vhdl/controllers/pcm_to_pdm.vhdl \
	$(PPRDIR)/vhdl/keyboard.vhd \
	$(PPRDIR)/vhdl/m65_const.vhd \
	$(PPRDIR)/vhdl/qnice_globals.vhd \
	$(PPRDIR)/vhdl/qnice_mmio.vhd \
	$(PPRDIR)/vhdl/video/vga_controller.vhd

VERILOG=\
	$(PPRDIR)/../rtl/gb.v \
	$(PPRDIR)/../rtl/hdma.v \
	$(PPRDIR)/../rtl/link.v \
	$(PPRDIR)/../rtl/sprites.v \
	$(PPRDIR)/../rtl/timer.v \
	$(PPRDIR)/../rtl/video.v \
	$(PPRDIR)/Verilog/mbc.sv


###################################################################
# Anything below here should probably not be changed
###################################################################

SOURCES = $(VHDL) $(VHDL2008) $(VERILOG)

BIT=build/$(BOARD).bit
MMI=build/$(BOARD).mmi
XDC=$(BOARD).xdc
TCL=build/$(BOARD).tcl
DCP=build/$(BOARD).dcp
MEM=build/$(BOARD).mem
ROM_BIT=build/$(BOARD)-rom.bit


bit: $(BIT)

# Generate the build script used by Vivado
$(TCL): Makefile
	mkdir -p build
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "read_vhdl -vhdl2008 { $(VHDL2008) }" >> $@
	echo "read_vhdl { $(VHDL) }" >> $@
	echo "read_verilog { $(VERILOG) }" >> $@
	echo "read_xdc $(XDC)" >> $@
	echo "set_property XPM_LIBRARIES {XPM_CDC} [current_project]" >> $@
	echo "synth_design -top $(TOP) -part xc7a200tfbg484-1 -flatten_hierarchy none" >> $@
	echo "opt_design" >> $@
	echo "place_design" >> $@
	echo "phys_opt_design" >> $@
	echo "route_design" >> $@
	echo "write_checkpoint -force $(DCP)" >> $@
	echo "write_bitstream -force $(BIT)" >> $@
	echo "set mmi_file $(MMI)" >> $@
	echo "source gen-mmi.tcl" >> $@
	echo "exit" >> $@

# Generate the bit-file used to configure the FPGA
$(BIT): $(TCL) $(SOURCES) $(XDC)
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

# Generate the mmi-file used for updating the bit-file with new QNICE ROM
$(MMI):
	@echo "You need to generate the .bit and .mmi file first"
	@exit -1

# Convert the QNICE ROM into a .mem file needed by the update utility
$(MEM): $(ROM)
	./rom2mem.py $(ROM) $(MEM)

# Update bit-file with new QNICE ROM
update: $(MMI) $(MEM)
	bash -c "source $(XILINX_DIR)/settings64.sh ; \
		updatemem -debug -meminfo $(MMI) -data $(MEM) -proc dummy -bit $(BIT) -out $(ROM_BIT) -force"

clean:
	rm -rf build
	rm -f updatemem*
	rm -f usage_statistics_webtalk.*
	rm -f vivado*
	rm -f webtalk*
	rm -rf CORE-R2.cache/
	rm -rf CORE-R2.hw/
	rm -rf CORE-R2.ip_user_files/
	rm -rf CORE-R2.runs/
	rm -rf CORE-R2.sim/
	rm -rf CORE-R3.cache/
	rm -rf CORE-R3.hw/
	rm -rf CORE-R3.ip_user_files/
	rm -rf CORE-R3.runs/
	rm -rf CORE-R3.sim/

