# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES += $(PWD)/../../src/dsp/math_utils_pkg.vhd
VHDL_SOURCES += $(PWD)/../../src/dsp/comb_filter_stage.vhd
VHDL_SOURCES += $(PWD)/../../src/dsp/comb_filter.vhd
VHDL_SOURCES += $(PWD)/../../src/dsp/raw_decimator.vhd
VHDL_SOURCES += $(PWD)/../../src/dsp/integrator_stage.vhd
VHDL_SOURCES += $(PWD)/../../src/dsp/integrator.vhd
VHDL_SOURCES += $(PWD)/../../src/dsp/dec_cic_filter.vhd

COCOTB_TOPLEVEL = dec_cic_filter

COCOTB_TEST_MODULES = dec_cic_filter_tb

SIM_ARGS += --wave=wave.vcd
SIM_ARGS += --dump-arrays
SIM_ARGS += -gDECIMATION_RATE_R=2
SIM_ARGS += -gINPUT_DATA_W=16
SIM_ARGS += -gDIFFERENTIAL_DELAY=1
SIM_ARGS += -gNUMBER_TAPS_N=1

include $(shell cocotb-config --makefiles)/Makefile.sim
