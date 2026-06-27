"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : cocotb / Python 3
-------------------------------------------------------------------------------
-- Rev  Author       Date        Description
-- 1.0  A. Thornton  cocotb      Cross-matrix testbench for float_add
-------------------------------------------------------------------------------
-- Description
--   cocotb testbench for the complec multiplier
-------------------------------------------------------------------------------
"""

import math
import itertools
import numpy as np

import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer


PIPELINE_DEPTH  = 2      # DUT latency in clock cycles
CLOCK_PERIOD_NS = 10
CLOCK_HOLD_NS   = 1

async def hold(dut):
    await Timer(CLOCK_HOLD_NS, 'ns')

async def initialise(dut):
    dut.real_i.value = 0
    dut.imag_i.value = 0
    dut.vld_i.value = 0

async def reset(dut):
    dut.srst_i.value = 1
    await ClockCycles(dut.clk_i,10)
    dut.srst_i.value = 0


@cocotb.test()
async def test_theta_values(dut):

    await initialise(dut)
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    await reset(dut)

    iterations = dut.ITERATIONS.value
    tb_theta_table_value = []
    OUTPUT_DATA_W = dut.OUTPUT_DATA_W.value
    for i in range(iterations):
        tb_theta_table_value.append(dut.theta_table[i].value.to_signed() * (2**(-(OUTPUT_DATA_W-1))))

    simulated_theta_table = [(math.atan2(1, 2**i))/(math.pi) for i in range(iterations)]

    for i in range(iterations):
        dut._log.info(f"Expected  theta[{i}] : {simulated_theta_table[i]}")
        dut._log.info(f"Testbench theta[{i}] : {tb_theta_table_value[i]}")
        error_pc = (abs(simulated_theta_table[i]-tb_theta_table_value[i])/simulated_theta_table[i]) * 100
        dut._log.info(f"error              : {error_pc}%\n")
        assert error_pc < 0.05

    await ClockCycles(dut.clk_i,10)


@cocotb.test()
async def test_pi_on_4(dut):

    await initialise(dut)
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    await reset(dut)
    dut.real_i.value = 1000
    dut.imag_i.value = 1000
    dut.vld_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.real_i.value = 0
    dut.imag_i.value = 0
    dut.vld_i.value = 0
    OUTPUT_DATA_W = dut.OUTPUT_DATA_W.value
    await RisingEdge(dut.clk_i)
    for i in range(1000):
        await RisingEdge(dut.clk_i)
        await hold(dut)
        if dut.vld_o.value == 1:
            output_value = (dut.phase_o.value.to_signed())*(2**(-(OUTPUT_DATA_W-1)))
            expected_value = 0.5
            dut._log.info(f"Testbench output_value : {output_value}")
            dut._log.info(f"Expected value         : {expected_value}")
            error = (abs(output_value-expected_value)/expected_value) * 100
            dut._log.info(f"error                  : {error}%\n")
            assert error < 0.1


    await ClockCycles(dut.clk_i,40)