# Makefile

# defaults
SIM = ghdl
TOPLEVEL_LANG = vhdl
GHDL_ARGS=--std=08

VHDL_SOURCES = $(PWD)/../and_gate.vhd

# COCOTB_TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = and_gate

# COCOTB_TEST_MODULES is the basename of the Python test file(s)
MODULE = and_gate_cocotb

VERBOSE = 1

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim