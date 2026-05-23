# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES += $(PWD)/../../src/floating_point/common_int_tools_pkg.vhd
VHDL_SOURCES += $(PWD)/../../src/floating_point/common_float_tools_pkg.vhd
VHDL_SOURCES += $(PWD)/../../src/floating_point/fixed_to_floating.vhd

COCOTB_TOPLEVEL = fixed_to_floating

COCOTB_TEST_MODULES = fixed_to_floating_tb

SIM_ARGS += --wave=wave.vcd
SIM_ARGS += -gINT_BITS=4
SIM_ARGS += -gFRAC_BITS=4

include $(shell cocotb-config --makefiles)/Makefile.sim
