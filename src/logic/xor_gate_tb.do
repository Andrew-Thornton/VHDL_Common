###############################################################################
## Author        : Andrew Thornton
## Creation Date : 2023-Dec-08
## Simulator     : ModelSim - Intel Starter Edition 10.5b
###############################################################################
## Rev  Author        Description
## 1.0  A. Thornton   Do file Creation
###############################################################################

vlib work
vcom -2008 ./xor_gate.vhd
vcom -2008 ./xor_gate_tb.vhd

vsim xor_gate_tb

add wave sim:/xor_gate_tb/*

run 1 ms

wave zoom full