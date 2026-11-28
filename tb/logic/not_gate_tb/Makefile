# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl

EXTRA_ARGS += --std=2008

VHDL_SOURCES += $(PWD)/../../../src/logic/not_gate.vhd

COCOTB_TOPLEVEL = not_gate

COCOTB_TEST_MODULES = not_gate_tb

SIM_ARGS += --wave=wave.vcd

include $(shell cocotb-config --makefiles)/Makefile.sim
