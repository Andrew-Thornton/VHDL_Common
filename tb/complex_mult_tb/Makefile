# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES += $(PWD)/../../src/dsp/complex_mult.vhd

COCOTB_TOPLEVEL = complex_mult

COCOTB_TEST_MODULES = complex_mult_tb

SIM_ARGS += --wave=wave.vcd
SIM_ARGS += --dump-arrays 

include $(shell cocotb-config --makefiles)/Makefile.sim
