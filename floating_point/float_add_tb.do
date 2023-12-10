###############################################################################
## This code is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This code is provided WITHOUT ANY WARRANTY; 
## without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
###############################################################################
## Author        : Andrew Thornton
## Creation Date : 2023-Dec-09
## Simulator     : ModelSim - Intel Starter Edition 10.5b
###############################################################################
## Rev  Author        Description
## 1.0  A. Thornton   Do file Creation
###############################################################################

#vlib dummy_ieee
#vcom -2008 ../1076-2008_downloads/1076-2008_machine-readable/ieee/float_generic_pkg.vhdl

vlib work
vcom -2008 ./common_float_tools_pkg.vhd
vcom -2008 ./float_add.vhd
vcom -2008 ./float_add_tb.vhd




vsim float_add_tb

#add wave sim:/float_add_tb/*
add wave sim:/float_add_tb/dut/*

run 1 ms

wave zoom full