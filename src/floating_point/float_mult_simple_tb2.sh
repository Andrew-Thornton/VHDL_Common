#!/usr/bin/env bash

#Compile the source files
ghdl -a --std=08 common_float_tools_pkg.vhd
ghdl -a --std=08 float_mult.vhd

#Compile the test bench
ghdl -a --std=08 float_mult_simple_tb2.vhd

#elaborate the testbench
ghdl -e --std=08 float_mult_simple_tb2

#run the testbench\
ghdl -r --std=08 float_mult_simple_tb2 --vcd=float_mult_simple_tb_wave2.vcd --stop-time=10us

gtkwave float_mult_simple_tb_wave2.vcd float_mult_simple_tb2.gtkw