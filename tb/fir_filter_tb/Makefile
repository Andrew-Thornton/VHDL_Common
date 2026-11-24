# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl

VHDL_LIB_ORDER = vhdl_common

EXTRA_ARGS += --std=2008

VHDL_SOURCES_vhdl_common += $(PWD)/../../src/common_pkg/common_types_pkg.vhd
VHDL_SOURCES_vhdl_common += $(PWD)/../../src/dsp/fir_filter_pkg.vhd
VHDL_SOURCES_vhdl_common += $(PWD)/../../src/dsp/math_utils_pkg.vhd

VHDL_SOURCES += $(PWD)/../../src/dsp/fir_filter.vhd

COCOTB_TOPLEVEL = fir_filter

COCOTB_TEST_MODULES = fir_filter_tb

SIM_ARGS += --wave=wave.vcd
SIM_ARGS += --dump-arrays
SIM_ARGS += -gINPUT_DATA_WIDTH=16
SIM_ARGS += -gOUTPUT_DATA_WIDTH=16
SIM_ARGS += -gSHIFT_RIGHT_BITS=12


include $(shell cocotb-config --makefiles)/Makefile.sim
