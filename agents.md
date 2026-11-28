# VHDL_Common project
The aim of this project is to create multiple re-usable vhdl 2008 code modules which can be re-used in a variety of FPGA / ASIC projects.

# Rules
all modules should follow a coding style with elements such as
_o for outputs
_i for inputs
p_ for process
All proccesses should have a name
All processes and instantiations should have a description above descibing what it is doing.
All modules that are not packages must have a cocotb pytest marked prod.
All testbenches should be run in .github/workdlows/run_testbenches.yml through pytest -n auto -m prod

# Simulator
Use the latest NVC simulator and cocotb testbenches.

