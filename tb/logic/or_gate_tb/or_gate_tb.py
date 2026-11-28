"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : cocotb / Python 3
-------------------------------------------------------------------------------
-- Rev  Author       Date         Description
-- 1.0  A. Thornton  2023-Dec-08  Testbench creation (or_gate_tb.vhd)
-- 2.0  A. Thornton  2026-Nov-28  Ported to cocotb, simulated with NVC
-- 2.1  A. Thornton  2026-Nov-28  pytest runner replaces the Makefile
-------------------------------------------------------------------------------
-- Description
--   cocotb testbench for the or_gate entity, equivalent to the legacy VHDL
--   testbench or_gate_tb.vhd kept alongside it in this directory.
--
--   The DUT is a registered 2-input OR gate with a synchronous, active-high
--   reset that forces c_o low. c_o updates on the rising edge after the
--   inputs are applied.
--
--   Timing matches the legacy testbench: a 1 MHz clock, reset held for
--   9 cycles and released on a rising edge, and each output checked a
--   hold time (1/10 of a clock period) after the edge that registers it.
--
--   Tests
--   -----
--   test_or_gate_truth_table
--       Applies every input combination after reset and checks c_o.
--       This is the check performed by or_gate_tb.vhd.
--   test_or_gate_reset
--       Holds reset with inputs that would drive c_o high, checks c_o
--       stays low, then releases reset and checks c_o goes high.
--
--   Running
--   -------
--   test_or_gate_runner (marked prod) builds the DUT with NVC and runs
--   the cocotb tests above inside the simulator. From the repo root:
--
--       pytest -m prod                every testbench
--       pytest tb/logic/or_gate_tb    this testbench only
--
--   wave.vcd is written next to this file, build output to sim_build/.
-------------------------------------------------------------------------------
"""

from pathlib import Path

import pytest
import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotb_tools.runner import get_runner

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CLOCK_PERIOD_NS = 1000                   # 1 MHz, as the legacy testbench
CLOCK_HOLD_NS   = CLOCK_PERIOD_NS // 10  # sample point after each rising edge
RESET_CYCLES    = 9

# (a_i, b_i, expected c_o)
TRUTH_TABLE = [
    (0, 0, 0),
    (0, 1, 1),
    (1, 0, 1),
    (1, 1, 1),
]

# a_i, b_i values that drive c_o high once out of reset
RESET_TEST_INPUTS = (0, 1)


# ---------------------------------------------------------------------------
# Helper coroutines
# ---------------------------------------------------------------------------

async def apply_reset(dut, a=0, b=0):
    """Start the clock and hold reset for RESET_CYCLES with a_i, b_i driven."""
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())

    dut.srst_i.value = 1
    dut.a_i.value    = a
    dut.b_i.value    = b

    await ClockCycles(dut.clk_i, RESET_CYCLES)


async def release_reset(dut):
    """De-assert reset just after a rising edge."""
    await RisingEdge(dut.clk_i)
    dut.srst_i.value = 0


async def sample_after_edge(dut):
    """Wait for the next rising edge plus the hold time, then return c_o."""
    await RisingEdge(dut.clk_i)
    await Timer(CLOCK_HOLD_NS, unit="ns")
    return dut.c_o.value


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_or_gate_truth_table(dut):
    """Check c_o for every a_i, b_i combination."""
    await apply_reset(dut)
    await release_reset(dut)

    for a, b, expected in TRUTH_TABLE:
        dut.a_i.value = a
        dut.b_i.value = b
        c = await sample_after_edge(dut)
        dut._log.info("%d or %d = %s", a, b, c)
        assert c == expected, f"error {a} or {b} was {c}, expected {expected}"

    await RisingEdge(dut.clk_i)


@cocotb.test()
async def test_or_gate_reset(dut):
    """Reset forces c_o low even when the inputs would drive it high."""
    a, b = RESET_TEST_INPUTS

    await apply_reset(dut, a, b)
    await Timer(CLOCK_HOLD_NS, unit="ns")
    c = dut.c_o.value
    assert c == 0, f"c_o was {c} in reset with a_i={a}, b_i={b}, expected 0"

    await release_reset(dut)
    c = await sample_after_edge(dut)
    assert c == 1, f"c_o was {c} after reset with a_i={a}, b_i={b}, expected 1"


# ---------------------------------------------------------------------------
# pytest runner
# ---------------------------------------------------------------------------

TB_DIR    = Path(__file__).resolve().parent
SRC_DIR   = TB_DIR.parents[2] / "src"  # tb/logic/or_gate_tb -> repo root
BUILD_DIR = TB_DIR / "sim_build"


@pytest.mark.prod
def test_or_gate_runner():
    """Build or_gate with NVC and run the cocotb tests in this module."""
    runner = get_runner("nvc")

    runner.build(
        sources=[SRC_DIR / "logic" / "or_gate.vhd"],
        hdl_toplevel="or_gate",
        build_args=["--std=2008"],
        build_dir=BUILD_DIR,
    )

    runner.test(
        hdl_toplevel="or_gate",
        test_module="or_gate_tb",
        test_dir=TB_DIR,
        test_args=["--wave=wave.vcd"],
    )
