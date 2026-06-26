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
    await input_task