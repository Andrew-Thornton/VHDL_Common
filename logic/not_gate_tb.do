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
## Creation Date : 2023-Dec-08
## Simulator     : ModelSim - Intel Starter Edition 10.5b
###############################################################################
## Rev  Author        Description
## 1.0  A. Thornton   Do file Creation
###############################################################################

vlib work
vcom -2008 ./not_gate.vhd
vcom -2008 ./not_gate_tb.vhd

vsim not_gate_tb

add wave sim:/not_gate_tb/*

run 1 ms

wave zoom full