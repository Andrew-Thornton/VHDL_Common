###############################################################################
## Copyright (C) 2023 Andrew Thornton - All Rights Reserved
## Please contact me via andrewthornton9619@gmail.com or via linkedin
## https://www.linkedin.com/in/andrew-thornton-976a95231/
## if you would like to use this code.
###############################################################################
## Author        : Andrew Thornton
## Creation Date : 2024-Jan-14
## Simulator     : ModelSim - Intel Starter Edition 10.5b
###############################################################################
## Rev  Author       Date        Description
## 1.0  A. Thornton  2024-Jan-14 Do file Creation
###############################################################################

vlib work
vcom -2008 ./common_float_tools_pkg.vhd
vcom -2008 ./float_add.vhd
vcom -2008 ./float_add_speed_tb.vhd

vsim float_add_speed_tb

add wave sim:/float_add_speed_tb/*
add wave -divider
add wave sim:/float_add_speed_tb/dut/*

run 10 ms

wave zoom full