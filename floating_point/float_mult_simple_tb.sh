#!/usr/bin/env bash

#Compile the source files
ghdl -a --std=08 common_float_tools_pkg.vhd
ghdl -a --std=08 float_mult.vhd

#Compile the test bench
ghdl -a --std=08 float_mult_simple_tb.vhd

#elaborate the testbench
ghdl -e --std=08 float_mult_simple_tb

#run the testbench\
ghdl -r --std=08 float_mult_simple_tb --vcd=float_mult_simple_tb_wave.vcd --stop-time=2us

gtkwave float_mult_simple_tb_wave.vcd float_mult_simple_tb.gtkw