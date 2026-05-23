"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : cocotb / Python 3
-------------------------------------------------------------------------------
-- Description
--   cocotb testbench for the fixed_to_floating entity.
--
--   The DUT is a Unkownn-stage pipeline so every stimulus applied at cycle N
--   produces a result at cycle N+6.
--
--   Strategy
--   --------
--   TBD
"""

import math
import itertools
import numpy as np

import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotb.types import LogicArray

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PIPELINE_DEPTH = 2      # DUT latency in clock cycles
ULP_TOLERANCE  = 1      # Acceptable difference in raw bit patterns for normals
CLOCK_PERIOD_NS = 10
CLOCK_HOLD_NS = 1

# ---------------------------------------------------------------------------
# Initialisation coroutine
# ---------------------------------------------------------------------------

async def initialise(dut):
    """Start clock, assert synchronous reset, flush pipeline."""
    dut._log.info("=== initialise: starting clock and reset ===")

    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start(start_high=False))

    dut.srst_i.value = 1
    dut.a_i.value    = 0

    # Hold reset for several cycles
    await ClockCycles(dut.clk_i, 8)

    # De-assert on a rising edge, then wait for pipeline to drain
    await RisingEdge(dut.clk_i)
    dut.srst_i.value = 0
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH + 2)

    dut._log.info("=== initialise: complete ===")


# ---------------------------------------------------------------------------
# Main test
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_simple_number(dut):
    """
    Apply every ordered (a, b) pair from STIMULUS_BITS to the DUT
    back-to-back, then verify each output PIPELINE_DEPTH cycles after
    its corresponding input was driven.
    """
    await initialise(dut)

    dut.a_i.value = LogicArray("00100000")  # +2.0
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)

    dut.a_i.value = LogicArray("11100000")  # -2.0
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)

    dut.a_i.value = LogicArray("00101000")  # 2.5
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)

    dut.a_i.value = LogicArray("11011000")  # -2.5
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)
    await Timer(CLOCK_HOLD_NS, unit="ns")

