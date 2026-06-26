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

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PIPELINE_DEPTH  = 2      # DUT latency in clock cycles
CLOCK_PERIOD_NS = 10
CLOCK_HOLD_NS   = 1

STIMULUS_INTS: list[int] = [
    0,
    1,
    -1,
    2,
    406,
    32767,
    -32768,
]

async def initialise(dut):
    dut.a_real_i.value = 0
    dut.a_imag_i.value = 0
    dut.b_real_i.value = 0
    dut.b_imag_i.value = 0
    dut.vld_i.value = 0

async def reset(dut):
    dut.srst_i.value = 1
    await ClockCycles(dut.clk_i,10)
    dut.srst_i.value = 0



async def data_inputter(dut,stimuli):
    for a,b in stimuli:
        dut.a_real_i.value = int(np.real(a))
        dut.a_imag_i.value = int(np.imag(a))
        dut.b_real_i.value = int(np.real(b))
        dut.b_imag_i.value = int(np.imag(b))
        dut.vld_i.value = 1
        await RisingEdge(dut.clk_i)
    dut.a_real_i.value = 0
    dut.a_imag_i.value = 0
    dut.b_real_i.value = 0
    dut.b_imag_i.value = 0
    dut.vld_i.value = 0

async def data_checker(dut,stimuli):
    for a,b in stimuli:
        expected_value = a*b
        expected_real = int(np.real(expected_value))
        expected_imag = int(np.imag(expected_value))
        received_real = dut.c_real_o.value.to_signed()
        received_imag = dut.c_imag_o.value.to_signed()
        dut._log.info(f"test a= {a}, b= {b},  expected {expected_real} + 1j*{expected_imag}")
        dut._log.info(f"test a= {a}, b= {b},  received {received_real} + 1j*{received_imag}")
        
        assert dut.vld_o.value == 1
        assert received_real == expected_real
        assert received_imag == expected_imag
        await RisingEdge(dut.clk_i)


@cocotb.test()
async def test_complex_mult_matrix(dut):
    """
    Apply every ordered (a, b) pair from STIMULUS_INTS to the DUT
    back-to-back, then verify each output PIPELINE_DEPTH cycles after
    its corresponding input was driven.
    """
    await initialise(dut)
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    await reset(dut)

    # Build the full ordered cross-product list
    pairs = list(itertools.product(STIMULUS_INTS, repeat=2))
    cmplx_stimuli = []
    for a_real, b_real in pairs:
        cmplx_stimuli.append(a_real + 1j*b_real)

    test_set = list(itertools.product(cmplx_stimuli, repeat=2))
    n     = len(test_set)

    # dut._log.info(f"Test set is:")
    # for a,b in test_set:
    #     dut._log.info(f"a = {a}, b = {b}")

    input_task = cocotb.start_soon(data_inputter(dut, test_set))
    await ClockCycles(dut.clk_i,PIPELINE_DEPTH+1)
    output_checker_task = cocotb.start_soon(data_checker(dut,test_set))
    await output_checker_task