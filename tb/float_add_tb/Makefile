# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES += $(PWD)/../../src/floating_point/float_add.vhd

COCOTB_TOPLEVEL = float_add

COCOTB_TEST_MODULES = float_add_tb

SIM_ARGS += --wave=wave.vcd

include $(shell cocotb-config --makefiles)/Makefile.sim
