import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def generate_clock(dut):
    """Generate clock pulses."""
    while(True):
        dut.clk_i.value = 0
        await Timer(1, units="ns")
        dut.clk_i.value = 1
        await Timer(1, units="ns")

async def generate_reset(dut):
    """Generate clock pulses."""
    dut.srst_i.value = 1
    for i in range(10):
        await RisingEdge(dut.clk_i)
    dut.srst_i.value = 0

@cocotb.test()
async def and_gate_all_values_test(dut):
    """Try accessing the design."""
    cocotb.fork(generate_clock(dut))
    cocotb.fork(generate_reset(dut))

    await FallingEdge(dut.srst_i)
    await FallingEdge(dut.clk_i)

    #test 1
    dut.a_i.value = 0
    dut.b_i.value = 0
    await RisingEdge(dut.clk_i)
    dut._log.info("test1: My inputs are %s and %s", dut.a_i.value, dut.b_i.value)
    await FallingEdge(dut.clk_i)
    dut._log.info("test1: My output is %s", dut.c_o.value)
    assert dut.c_o.value == 0, "c_o is not 0!"

    #test 2
    dut.a_i.value = 1
    dut.b_i.value = 0
    await RisingEdge(dut.clk_i)
    dut._log.info("test2: My inputs are %s and %s", dut.a_i.value, dut.b_i.value)
    await FallingEdge(dut.clk_i)
    dut._log.info("test2: My output is %s", dut.c_o.value)
    assert dut.c_o.value == 0, "c_o is not 0!"

    #test 3
    dut.a_i.value = 0
    dut.b_i.value = 1
    await RisingEdge(dut.clk_i)
    dut._log.info("test3: My inputs are %s and %s", dut.a_i.value, dut.b_i.value)
    await FallingEdge(dut.clk_i)
    dut._log.info("test3: My output is %s", dut.c_o.value)
    assert dut.c_o.value == 0, "c_o is not 0!"

    #test 4
    dut.a_i.value = 1
    dut.b_i.value = 1
    await RisingEdge(dut.clk_i)
    dut._log.info("test4: My inputs are %s and %s", dut.a_i.value, dut.b_i.value)
    await FallingEdge(dut.clk_i)
    dut._log.info("test4: My output is %s", dut.c_o.value)
    assert dut.c_o.value == 1, "c_o is not 1!"




