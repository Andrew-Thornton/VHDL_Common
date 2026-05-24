"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : cocotb / Python 3
-------------------------------------------------------------------------------
-- Rev  Author       Date        Description
-- 1.0  A. Thornton  cocotb      
-------------------------------------------------------------------------------
-- Description
--   cocotb testbench for the Raw decimator tb, 
--
--   Makes sure all numbers which output are the second number entity.
-------------------------------------------------------------------------------
"""

import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PIPELINE_DEPTH  = 1     # DUT latency in clock cycles
CLOCK_PERIOD_NS = 10
CLOCK_HOLD_NS   = 1


# ---------------------------------------------------------------------------
# Initialisation coroutine
# ---------------------------------------------------------------------------

async def initialise(dut):
    """Start clock, assert synchronous reset, flush pipeline."""
    dut._log.info("=== initialise: starting clock and reset ===")

    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())

    dut.srst_i.value  = 1
    dut.a_i.value     = 0
    dut.a_vld_i.value = 0

    # Hold reset for several cycles
    await ClockCycles(dut.clk_i, 8)

    # De-assert on a rising edge, then wait for pipeline to drain
    await RisingEdge(dut.clk_i)
    dut.srst_i.value = 0
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH + 2)

    dut._log.info("=== initialise: complete ===")


async def data_inputter(dut, number_samples):
    for counter in range(number_samples):
        dut.a_i.value = counter
        dut.a_vld_i.value = 1
        await RisingEdge(dut.clk_i)

# ---------------------------------------------------------------------------
# Checker coroutine
# ---------------------------------------------------------------------------

async def simple_output_checker(dut, decimation_rate):
    first = True
    value = 0
    val_prev = 0
    while(True):
        if dut.b_vld_o.value == 1:
            if first == False:
                val_prev = value
                value = dut.b_o.value.to_signed()
                diff = value - val_prev
                assert diff == decimation_rate, (
                    f" difference in values was {diff}, expected {decimation_rate}"
                )
            else: #first
                val_prev = dut.b_o.value
                first = False
        await ClockCycles(dut.clk_i, 1)
        await Timer(CLOCK_HOLD_NS, unit="ns")   
    
# ---------------------------------------------------------------------------
# Main test
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_raw_decimator(dut):
    """
    Applys a counter input and checks that the output is every DECIMATION_RATE_R samples
    """
    await initialise(dut)

    number_samples = 1000
    data_input_task = cocotb.start_soon(data_inputter(dut, number_samples))

    # ------------------------------------------------------------------
    # Phase 2 – let the last transaction propagate through the pipeline
    # ------------------------------------------------------------------
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)
    await Timer(CLOCK_HOLD_NS, unit="ns")

    # ------------------------------------------------------------------
    # Phase 3 – check the outputs
    # ------------------------------------------------------------------
    decimation_rate = dut.DECIMATION_RATE_R.value
    dut._log.info(f'Decimation rate is {decimation_rate}')
    checking_results_task = cocotb.start_soon(simple_output_checker(dut, decimation_rate))

    await data_input_task
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)
    await Timer(CLOCK_HOLD_NS, unit="ns")

    dut._log.info(f"Test_raw_decimator complete")
