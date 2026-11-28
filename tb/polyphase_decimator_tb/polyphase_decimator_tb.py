"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : cocotb / Python 3
-------------------------------------------------------------------------------
-- Rev  Author       Date         Description
-- 1.0  A. Thornton  2026-Nov-28  Testbench creation
-------------------------------------------------------------------------------
-- Description
--   cocotb testbench for the polyphase_decimator entity, a decimate-by-2
--   polyphase FIR with multipliers shared over CLOCKS_PER_INPUT clocks.
--
--   The DUT is wrapped by polyphase_decimator_wrapper.vhd, which selects a
--   PG269 coefficient set (FIR1A, FIR2 or FIR3) from fir_filter_pkg with its
--   unity DC gain shift. The testbench parses the coefficients from
--   fir_filter_pkg.vhd, so the VHDL package is the only copy of them.
--
--   Every output is checked bit-exactly against polyphase_decimator_model,
--   which filters at the full input rate and keeps every second output, so a
--   pass shows the polyphase structure matches filter-then-decimate.
--
--   Tests
--   -----
--   test_impulse_response
--       An impulse on an even input and another on an odd input, checking
--       both polyphase branches are wired to the right taps.
--   test_noise_regular
--       Random samples, one every CLOCKS_PER_INPUT clocks. Also checks the
--       outputs are 2*CLOCKS_PER_INPUT clocks apart with constant latency.
--   test_noise_irregular
--       Random samples with random gaps of CLOCKS_PER_INPUT to
--       3*CLOCKS_PER_INPUT clocks, and junk on data_i while vld_i is low.
--   test_reset_mid_stream
--       Reset while the pipeline is busy and after an odd number of inputs,
--       then checks a new stream starts cleanly on the even phase.
--   test_multiplier_count
--       The DUT instantiates ceil(ceil(TAPS/2) / CLOCKS_PER_INPUT)
--       multipliers, no more than TAPS/CLOCKS_PER_INPUT.
--
--   test_rfsoc_half_band_coefficients (pytest only, no simulator)
--       Each PG269 set in fir_filter_pkg is a valid half-band filter, which
--       catches a mistyped coefficient.
--
--   Running
--   -------
--   test_polyphase_decimator_runner (marked prod) is parametrised over every
--   coefficient set and CLOCKS_PER_INPUT in CLOCKS_PER_INPUT_VALUES. From the
--   repo root:
--
--       pytest -m prod                         every testbench
--       pytest tb/polyphase_decimator_tb       this testbench only
--
--   Each configuration builds and simulates in its own sim_build/<config>/
--   directory, which also holds its wave.fst.
-------------------------------------------------------------------------------
"""

import os
import random
import re
from pathlib import Path

import numpy as np

import pytest
import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb_tools.runner import get_runner

from polyphase_decimator_model import (
    polyphase_decimator_model,
    multipliers,
    slots,
    latency_clocks,
    safe_amplitude,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CLOCK_PERIOD_NS = 10
RESET_CYCLES    = 10

STREAM_SAMPLES   = 1024     # input samples per noise test (512 outputs)
NOISE_SEED       = 2026
IRREGULAR_SEED   = 7
MAX_GAP_FACTOR   = 3        # irregular gaps are CLOCKS_PER_INPUT..3*CLOCKS_PER_INPUT
JUNK_DATA        = -12345   # driven on data_i while vld_i is low

FILTERS                 = ["FIR1A", "FIR2", "FIR3"]
CLOCKS_PER_INPUT_VALUES = [1, 3, 4, 16]

TB_DIR         = Path(__file__).resolve().parent
SRC_DIR        = TB_DIR.parents[1] / "src"  # tb/polyphase_decimator_tb -> repo root
BUILD_DIR      = TB_DIR / "sim_build"
FIR_FILTER_PKG = SRC_DIR / "dsp" / "fir_filter_pkg.vhd"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def read_coefficient_set(name):
    """
    Read RFSOC_<name>_COEF, _COEF_BITS and _GAIN_BITS from fir_filter_pkg.vhd.

    The VHDL package is the only copy of the coefficients. They are parsed
    from source because reading the COEFFICIENTS generic through VHPI crashes
    NVC 1.23.1.
    """
    text = FIR_FILTER_PKG.read_text()

    def natural_constant(suffix):
        match = re.search(rf"constant\s+RFSOC_{name}_{suffix}\s*:\s*natural\s*:=\s*(\d+)\s*;", text)
        assert match, f"RFSOC_{name}_{suffix} not found in {FIR_FILTER_PKG.name}"
        return int(match.group(1))

    match = re.search(rf"constant\s+RFSOC_{name}_COEF\s*:[^;]*?:=(.*?);", text, re.S)
    assert match, f"RFSOC_{name}_COEF not found in {FIR_FILTER_PKG.name}"
    coefficients = [int(v) for v in re.findall(r"to_signed\(\s*(-?\d+)\s*,", match.group(1))]

    taps = natural_constant("TAPS")
    assert len(coefficients) == taps, (
        f"RFSOC_{name}_COEF has {len(coefficients)} values, RFSOC_{name}_TAPS is {taps}"
    )
    return coefficients, natural_constant("COEF_BITS"), natural_constant("GAIN_BITS")


class DecimatorConfig:
    """Configuration of the DUT: generics from the simulation, coefficients from the package."""

    def __init__(self, dut):
        self.filter_select    = os.environ["FILTER_SELECT"]
        self.coefficients, _, self.shift_right_bits = read_coefficient_set(self.filter_select)
        self.taps             = len(self.coefficients)
        self.clocks_per_input = int(dut.CLOCKS_PER_INPUT.value)
        self.input_width      = int(dut.INPUT_DATA_WIDTH.value)
        self.output_width     = int(dut.OUTPUT_DATA_WIDTH.value)

        self.multipliers = multipliers(self.taps, self.clocks_per_input)
        self.slots       = slots(self.taps, self.clocks_per_input)
        self.latency     = latency_clocks(self.taps, self.clocks_per_input)
        self.amplitude   = safe_amplitude(self.coefficients, self.shift_right_bits,
                                          self.input_width, self.output_width)

    def log(self, dut):
        dut._log.info(
            f"{self.filter_select}: TAPS={self.taps} CLOCKS_PER_INPUT={self.clocks_per_input} "
            f"MULTIPLIERS={self.multipliers} SLOTS={self.slots} "
            f"latency={self.latency} SHIFT_RIGHT_BITS={self.shift_right_bits} "
            f"amplitude={self.amplitude}"
        )


class StreamMonitor:
    """
    Records (cycle, value) for every input and output, sampling vld_i/data_i
    and vld_o/data_o on each rising edge (the values the DUT registers there).
    """

    def __init__(self, dut):
        self.inputs  = []
        self.outputs = []
        self._task   = cocotb.start_soon(self._run(dut))

    async def _run(self, dut):
        cycle = 0
        while True:
            await RisingEdge(dut.clk_i)
            cycle += 1
            if dut.vld_i.value == 1:
                self.inputs.append((cycle, dut.data_i.value.to_signed()))
            if dut.vld_o.value == 1:
                self.outputs.append((cycle, dut.data_o.value.to_signed()))

    def stop(self):
        self._task.cancel()


async def start(dut):
    """Start the clock, drive idle inputs and reset the DUT."""
    cocotb.start_soon(Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns").start())
    dut.data_i.value = 0
    dut.vld_i.value  = 0
    await reset(dut)


async def reset(dut):
    """Hold srst_i for RESET_CYCLES clocks, releasing it after a rising edge."""
    dut.srst_i.value = 1
    await ClockCycles(dut.clk_i, RESET_CYCLES)
    dut.srst_i.value = 0


async def drive(dut, samples, gaps):
    """
    Drive each sample with vld_i high for one clock. gaps[i] is the number of
    clocks from sample i to sample i+1; data_i carries junk in between.
    """
    for sample, gap in zip(samples, gaps):
        dut.data_i.value = int(sample)
        dut.vld_i.value  = 1
        await RisingEdge(dut.clk_i)
        dut.vld_i.value  = 0
        dut.data_i.value = JUNK_DATA
        if gap > 1:
            await ClockCycles(dut.clk_i, gap - 1)


async def drain(dut, config):
    """Wait long enough for the last output to leave the pipeline."""
    await ClockCycles(dut.clk_i, config.latency + 2 * config.clocks_per_input + 4)


def random_samples(config, n, seed):
    rng = np.random.default_rng(seed)
    return rng.integers(-config.amplitude, config.amplitude + 1, size=n)


def check_outputs(dut, config, monitor, samples):
    """Outputs must match the model exactly, one per pair of inputs."""
    expected = polyphase_decimator_model(samples, config.coefficients, config.shift_right_bits)
    got = np.array([value for _, value in monitor.outputs], dtype=np.int64)

    assert len(got) == len(expected), (
        f"expected {len(expected)} outputs for {len(samples)} inputs, got {len(got)}"
    )
    mismatches = np.nonzero(got != expected)[0]
    assert len(mismatches) == 0, (
        f"{len(mismatches)} of {len(expected)} outputs differ from the model, first at "
        f"output {mismatches[0]}: got {got[mismatches[0]]}, expected {expected[mismatches[0]]}"
    )
    dut._log.info(f"{len(got)} outputs match the model bit-exactly")


def check_latency(config, monitor):
    """
    Each output follows the odd input of its pair by the RTL latency. The
    monitor sees vld_o on the edge after it rises, hence the + 1.
    """
    odd_input_cycles = [cycle for cycle, _ in monitor.inputs][1::2]
    output_cycles    = [cycle for cycle, _ in monitor.outputs]
    observed = {o - i for i, o in zip(odd_input_cycles, output_cycles)}
    assert observed == {config.latency + 1}, (
        f"output latency after the odd input was {sorted(observed)} clocks, "
        f"expected {config.latency + 1}"
    )


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_impulse_response(dut):
    """Impulses on an even and an odd input exercise each polyphase branch."""
    config = DecimatorConfig(dut)
    config.log(dut)
    await start(dut)

    # the second impulse is on an odd sample, after the first has died away
    odd_start = config.taps + 1 if config.taps % 2 == 0 else config.taps + 2
    samples = np.zeros(odd_start + config.taps + 1, dtype=np.int64)
    samples[0]         = config.amplitude
    samples[odd_start] = -config.amplitude

    monitor = StreamMonitor(dut)
    await drive(dut, samples, [config.clocks_per_input] * len(samples))
    await drain(dut, config)
    monitor.stop()

    check_outputs(dut, config, monitor, samples)
    check_latency(config, monitor)


@cocotb.test()
async def test_noise_regular(dut):
    """Random samples at the full rate of one every CLOCKS_PER_INPUT clocks."""
    config = DecimatorConfig(dut)
    await start(dut)

    samples = random_samples(config, STREAM_SAMPLES, NOISE_SEED)

    monitor = StreamMonitor(dut)
    await drive(dut, samples, [config.clocks_per_input] * len(samples))
    await drain(dut, config)
    monitor.stop()

    check_outputs(dut, config, monitor, samples)
    check_latency(config, monitor)

    output_cycles = [cycle for cycle, _ in monitor.outputs]
    spacing = set(np.diff(output_cycles).tolist())
    assert spacing == {2 * config.clocks_per_input}, (
        f"outputs were {sorted(spacing)} clocks apart, "
        f"expected {2 * config.clocks_per_input}"
    )


@cocotb.test()
async def test_noise_irregular(dut):
    """Random samples with random gaps, junk on data_i while vld_i is low."""
    config = DecimatorConfig(dut)
    await start(dut)

    samples = random_samples(config, STREAM_SAMPLES, NOISE_SEED + 1)
    rng = random.Random(IRREGULAR_SEED)
    cpi = config.clocks_per_input
    gaps = [rng.randint(cpi, MAX_GAP_FACTOR * cpi) for _ in samples]

    monitor = StreamMonitor(dut)
    await drive(dut, samples, gaps)
    await drain(dut, config)
    monitor.stop()

    check_outputs(dut, config, monitor, samples)
    check_latency(config, monitor)


@cocotb.test()
async def test_reset_mid_stream(dut):
    """A reset mid-stream clears the delay lines, pipeline and input phase."""
    config = DecimatorConfig(dut)
    await start(dut)

    # An odd number of inputs flips the input phase and resetting straight
    # away catches products still in the pipeline. Two rounds mean one of
    # them starts on the odd phase whatever state earlier tests left, so a
    # reset that does not clear the phase is always caught.
    for round_ in range(2):
        first = random_samples(config, 2 * config.taps + 1, NOISE_SEED + 2 + 2 * round_)
        await drive(dut, first, [config.clocks_per_input] * len(first))
        await reset(dut)

        samples = random_samples(config, 4 * config.taps, NOISE_SEED + 3 + 2 * round_)
        monitor = StreamMonitor(dut)
        await drive(dut, samples, [config.clocks_per_input] * len(samples))
        await drain(dut, config)
        monitor.stop()

        check_outputs(dut, config, monitor, samples)
        check_latency(config, monitor)


@cocotb.test()
async def test_multiplier_count(dut):
    """The DUT shares ceil(ceil(TAPS/2) / CLOCKS_PER_INPUT) multipliers."""
    config = DecimatorConfig(dut)
    config.log(dut)

    instantiated = len(dut.dut_i.mult_terms)
    assert instantiated == config.multipliers, (
        f"DUT has {instantiated} multipliers, expected {config.multipliers}"
    )

    budget = -(-config.taps // config.clocks_per_input)
    assert instantiated <= budget, (
        f"{instantiated} multipliers is more than ceil(TAPS/CLOCKS_PER_INPUT) = {budget}"
    )
    dut._log.info(
        f"{instantiated} multipliers for {config.taps} taps at one input every "
        f"{config.clocks_per_input} clocks (ceil(TAPS/CLOCKS_PER_INPUT) = {budget})"
    )


# ---------------------------------------------------------------------------
# pytest tests
# ---------------------------------------------------------------------------

@pytest.mark.prod
@pytest.mark.parametrize("filter_select", FILTERS)
def test_rfsoc_half_band_coefficients(filter_select):
    """
    The PG269 sets in fir_filter_pkg are valid half-band filters: symmetric,
    zero at every even offset from the centre tap, a power of two centre tap
    equal to the sum of the other taps, and 2**GAIN_BITS DC gain. A mistyped
    coefficient breaks these exact sums.
    """
    coefficients, coef_bits, gain_bits = read_coefficient_set(filter_select)
    h = np.array(coefficients, dtype=np.int64)
    centre = len(h) // 2

    assert len(h) % 2 == 1, "half-band filters have an odd number of taps"
    assert np.array_equal(h, h[::-1]), "coefficients are not symmetric"
    assert all(h[centre + offset] == 0 for offset in range(2, centre + 1, 2)), (
        "non-zero tap at an even offset from the centre"
    )
    assert h[centre] & (h[centre] - 1) == 0, f"centre tap {h[centre]} is not a power of two"
    assert h.sum() - h[centre] == h[centre], "side taps do not sum to the centre tap"
    assert h.sum() == 2 ** gain_bits, f"DC gain {h.sum()} is not 2**{gain_bits}"
    assert np.abs(h).max() < 2 ** (coef_bits - 1), f"coefficients do not fit {coef_bits} bits"


@pytest.mark.prod
@pytest.mark.parametrize("clocks_per_input", CLOCKS_PER_INPUT_VALUES, ids=lambda c: f"cpi{c}")
@pytest.mark.parametrize("filter_select", FILTERS)
def test_polyphase_decimator_runner(filter_select, clocks_per_input):
    """Build polyphase_decimator with NVC and run the cocotb tests in this module."""
    runner = get_runner("nvc")
    build_dir = BUILD_DIR / f"{filter_select}_cpi{clocks_per_input}"

    runner.build(
        sources=[
            SRC_DIR / "common_pkg" / "common_types_pkg.vhd",
            SRC_DIR / "dsp" / "math_utils_pkg.vhd",
            SRC_DIR / "dsp" / "fir_filter_pkg.vhd",
            SRC_DIR / "dsp" / "polyphase_decimator.vhd",
        ],
        hdl_library="vhdl_common",
        build_args=["--std=2008"],
        build_dir=build_dir,
    )

    runner.build(
        sources=[TB_DIR / "polyphase_decimator_wrapper.vhd"],
        hdl_toplevel="polyphase_decimator_wrapper",
        build_args=["--std=2008"],
        build_dir=build_dir,
    )

    runner.test(
        hdl_toplevel="polyphase_decimator_wrapper",
        test_module="polyphase_decimator_tb",
        test_dir=build_dir,
        parameters={
            "FILTER_SELECT": filter_select,
            "CLOCKS_PER_INPUT": clocks_per_input,
        },
        extra_env={"FILTER_SELECT": filter_select},
        test_args=["--wave=wave.fst"],
    )
