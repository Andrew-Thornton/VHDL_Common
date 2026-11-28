"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : cocotb / Python 3
-------------------------------------------------------------------------------
-- Rev  Author       Date         Description
-- 1.0  A. Thornton  2023-Dec-08  Testbench creation (not_gate_tb.vhd)
-- 2.0  A. Thornton  2026-Nov-28  Ported to cocotb, simulated with NVC
-------------------------------------------------------------------------------
-- Description
--   cocotb testbench for the not_gate entity, equivalent to the legacy VHDL
--   testbench not_gate_tb.vhd kept alongside it in this directory.
--
--   The DUT is a registered NOT gate (inverter) with a synchronous, active-high
--   reset that forces b_o low. b_o updates on the rising edge after the
--   inputs are applied.
--
--   Timing matches the legacy testbench: a 1 MHz clock, reset held for
--   9 cycles and released on a rising edge, and each output checked a
--   hold time (1/10 of a clock period) after the edge that registers it.
--
--   Tests
--   -----
--   test_not_gate_truth_table
--       Applies every input combination after reset and checks b_o.
--       This is the check performed by not_gate_tb.vhd.
--   test_not_gate_reset
--       Holds reset with inputs that would drive b_o high, checks b_o
--       stays low, then releases reset and checks b_o goes high.
-------------------------------------------------------------------------------
"""

import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CLOCK_PERIOD_NS = 1000                   # 1 MHz, as the legacy testbench
CLOCK_HOLD_NS   = CLOCK_PERIOD_NS // 10  # sample point after each rising edge
RESET_CYCLES    = 9

# (a_i, expected b_o)
TRUTH_TABLE = [
    (0, 1),
    (1, 0),
]

# a_i value that drives b_o high once out of reset
RESET_TEST_INPUT = 0


# ---------------------------------------------------------------------------
# Helper coroutines
# ---------------------------------------------------------------------------

async def apply_reset(dut, a=0):
    """Start the clock and hold reset for RESET_CYCLES with a_i driven."""
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())

    dut.srst_i.value = 1
    dut.a_i.value    = a

    await ClockCycles(dut.clk_i, RESET_CYCLES)


async def release_reset(dut):
    """De-assert reset just after a rising edge."""
    await RisingEdge(dut.clk_i)
    dut.srst_i.value = 0


async def sample_after_edge(dut):
    """Wait for the next rising edge plus the hold time, then return b_o."""
    await RisingEdge(dut.clk_i)
    await Timer(CLOCK_HOLD_NS, unit="ns")
    return dut.b_o.value


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_not_gate_truth_table(dut):
    """Check b_o for both values of a_i."""
    await apply_reset(dut)
    await release_reset(dut)

    for a, expected in TRUTH_TABLE:
        dut.a_i.value = a
        b = await sample_after_edge(dut)
        dut._log.info("not(%d) = %s", a, b)
        assert b == expected, f"error not({a}) was {b}, expected {expected}"

    await RisingEdge(dut.clk_i)


@cocotb.test()
async def test_not_gate_reset(dut):
    """Reset forces b_o low even when the input would drive it high."""
    a = RESET_TEST_INPUT

    await apply_reset(dut, a)
    await Timer(CLOCK_HOLD_NS, unit="ns")
    b = dut.b_o.value
    assert b == 0, f"b_o was {b} in reset with a_i={a}, expected 0"

    await release_reset(dut)
    b = await sample_after_edge(dut)
    assert b == 1, f"b_o was {b} after reset with a_i={a}, expected 1"
