###############################################################################
## Copyright (C) 2023 Andrew Thornton - All Rights Reserved
## Please contact me via andrewthornton9619@gmail.com or via linkedin
## https://www.linkedin.com/in/andrew-thornton-976a95231/
## if you would like to use this code.
###############################################################################
## Author        : Andrew Thornton
## Creation Date : 2023-Dec-09
## Simulator     : ModelSim - Intel Starter Edition 10.5b
###############################################################################
## Rev  Author        Description
## 1.0  A. Thornton   Do file Creation
## 1.1  A. Thornton   Added more waves for viewing, changed licensing
## 1.2  A. Thornton   Removed commented code
###############################################################################

vlib work
vcom -2008 ./common_float_tools_pkg.vhd
vcom -2008 ./float_add.vhd
vcom -2008 ./float_add_tb.vhd

vsim float_add_tb

add wave sim:/float_add_tb/*
add wave sim:/float_add_tb/dut/*

run 1 ms

wave zoom full