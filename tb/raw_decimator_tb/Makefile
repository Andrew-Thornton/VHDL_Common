# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl

VHDL_LIB_ORDER = vhdl_common

VHDL_SOURCES_vhdl_common += $(PWD)/../../src/dsp/math_utils_pkg.vhd
VHDL_SOURCES += $(PWD)/../../src/dsp/raw_decimator.vhd

COCOTB_TOPLEVEL = raw_decimator

COCOTB_TEST_MODULES = raw_decimator_tb

SIM_ARGS += --wave=wave.vcd
SIM_ARGS += -gDECIMATION_RATE_R=2
SIM_ARGS += -gINPUT_DATA_W=16

include $(shell cocotb-config --makefiles)/Makefile.sim
