# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES += $(PWD)/../../src/floating_point/float_mult.vhd

COCOTB_TOPLEVEL = float_mult

COCOTB_TEST_MODULES = float_mult_tb

SIM_ARGS += --wave=wave.vcd

include $(shell cocotb-config --makefiles)/Makefile.sim
