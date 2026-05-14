#!/bin/bash
###############################################################################
## Copyright (C) 2023 Andrew Thornton - All Rights Reserved
## Please contact me via andrewthornton9619@gmail.com or via linkedin
## https://www.linkedin.com/in/andrew-thornton-976a95231/
## if you would like to use this code.
###############################################################################
## Author        : Andrew Thornton
## Creation Date : 2024-Jan-14
## Simulator     : NVC
###############################################################################
## Rev  Author       Date        Description
## 1.0  A. Thornton  2024-Jan-14 Do file Creation
## 1.1  A. Thornton  2024-Jan-14 Increased simulation time
## 1.2  A. Thornton  2024-Jan-14 Converted from ModelSim .do to NVC shell script
###############################################################################

# Analyse VHDL source files (equivalent to vcom -2008)
nvc --std=2008 -a ./../../src/floating_point/common_float_tools_pkg.vhd
nvc --std=2008 -a ./../../src/floating_point/float_add.vhd
nvc --std=2008 -a ./float_add_speed_tb.vhd

# Elaborate the top-level testbench (equivalent to vsim)
nvc --std=2008 -e float_add_speed_tb

# Run simulation for 100 ms and dump all signals to wave.vcd
# --vcd=wave.vcd captures all signals (equivalent to "add wave sim:/float_add_speed_tb/*"
# and "add wave sim:/float_add_speed_tb/dut/*")
nvc --std=2008 -r float_add_speed_tb --wave=wave.vcd --stop-time=100ms
