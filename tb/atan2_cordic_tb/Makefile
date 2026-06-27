# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES += $(PWD)/../../src/dsp/atan2_cordic.vhd

COCOTB_TOPLEVEL = atan2_cordic

COCOTB_TEST_MODULES = atan2_cordic_tb

SIM_ARGS += --wave=wave.vcd
SIM_ARGS += --dump-arrays 

VHDL_STANDARD = 2008

include $(shell cocotb-config --makefiles)/Makefile.sim
