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
--   Both noise tests save the input and output spectra in dBFS, with the
--   output expected from the coefficients, to plots/<config>_<test>_fft.png.
--   test_two_tone
--       Sines at 0.01 and 0.4 cycles per input sample. 0.01 is in the
--       passband and 0.4 in the stopband, where any residual aliases to 0.1
--       after decimation. Saves the input and output waveforms and spectra
--       to plots/<config>_two_tone.png.
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
--   directory, which also holds its wave.fst. Spectrum plots for review go
--   to plots/, named by configuration and test.
-------------------------------------------------------------------------------
"""

import os
import random
import re
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")  # headless backend: simulations rarely have a display
import matplotlib.pyplot as plt

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

STREAM_SAMPLES   = 16384    # input samples per noise test (8192 outputs), enough for ~31 FFT averages
NOISE_SEED       = 2026
IRREGULAR_SEED   = 7
MAX_GAP_FACTOR   = 3        # irregular gaps are CLOCKS_PER_INPUT..3*CLOCKS_PER_INPUT
JUNK_DATA        = -12345   # driven on data_i while vld_i is low

TONE_FREQS       = (0.01, 0.4)  # cycles per input sample: one passband, one stopband tone
TONE_SEED        = 11           # dither seed for the two tone test
TIME_PLOT_INPUTS = 200          # input samples shown in the two tone time domain plot

FILTERS                 = ["FIR1A", "FIR2", "FIR3"]
CLOCKS_PER_INPUT_VALUES = [1, 3, 4, 16]

TB_DIR         = Path(__file__).resolve().parent
SRC_DIR        = TB_DIR.parents[1] / "src"  # tb/polyphase_decimator_tb -> repo root
BUILD_DIR      = TB_DIR / "sim_build"
FIR_FILTER_PKG = SRC_DIR / "dsp" / "fir_filter_pkg.vhd"
PLOT_DIR       = TB_DIR / "plots"

# Spectrum plots: FFTs of FFT_SEGMENT_INPUTS input samples (and half as many
# outputs, so both have the same frequency resolution), Hann windowed, 50%
# overlapped and averaged so the noise spectra are readable. The FFT size sets
# the resolution; STREAM_SAMPLES / (FFT_SEGMENT_INPUTS/2) sets how many FFTs
# are averaged, which is what makes the noise spectra smooth.
FFT_SEGMENT_INPUTS = 1024

# Plot colours (validated categorical pair + neutral ink)
COLOUR_INPUT     = "#257de0"
COLOUR_OUTPUT    = "#f47230"
COLOUR_REFERENCE = "#666666"


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


def hann(n):
    """Periodic Hann window, the usual choice for spectral analysis."""
    return np.hanning(n + 1)[:-1]


def averaged_fft_power(x, segment):
    """
    Mean |X[k]|^2 of Hann windowed, 50% overlapped FFTs of `segment` samples
    (Welch's method). Returns the power per bin and the number of FFTs averaged.
    """
    x = np.asarray(x, dtype=np.float64)
    window = hann(segment)
    starts = range(0, len(x) - segment + 1, segment // 2)
    power = np.mean([np.abs(np.fft.rfft(window * x[s:s + segment])) ** 2 for s in starts], axis=0)
    return power, len(starts)


def to_dbfs(power, segment, full_scale):
    """
    Convert FFT bin power to dBFS: a full-scale sine (amplitude full_scale)
    puts |X[k]| = full_scale * sum(window) / 2 in its bin, which reads 0 dBFS.
    Noise is spread over all bins, so its level per bin falls 3 dB each time
    the FFT size doubles.
    """
    peak = full_scale * np.sum(hann(segment)) / 2.0
    return 10.0 * np.log10(np.maximum(power / peak ** 2, 1e-20))


def frequency_response(config, freqs):
    """Complex response H(f) of the filter including the output shift, f in cycles per input sample."""
    h = np.asarray(config.coefficients, dtype=np.float64) / 2.0 ** config.shift_right_bits
    return np.exp(-2j * np.pi * np.outer(np.atleast_1d(freqs), np.arange(len(h)))) @ h


def expected_output_power(config, samples, segment, freqs):
    """
    FFT bin power of the output expected from the coefficients, for a white
    noise input with the variance of `samples`, at freqs in cycles per input
    sample (0 to 0.25). Decimating by 2 folds the filtered spectrum at f and
    0.5-f onto the same output frequency, and halves the output power per
    output-rate bin, so with H the filter response including the shift
        E|Y[k]|^2 = var(x) * (|H(f)|^2 + |H(0.5 - f)|^2) / 2 * sum(window^2)
    """
    folded = (np.abs(frequency_response(config, freqs)) ** 2
              + np.abs(frequency_response(config, 0.5 - freqs)) ** 2)
    return np.var(np.asarray(samples, dtype=np.float64)) * folded / 2.0 * np.sum(hann(segment) ** 2)


def draw_spectra(ax, config, inputs, outputs):
    """
    Plot the input and output spectra on ax in dBFS of each port's own width,
    on one axis in cycles per input sample. The output FFT is half the input
    FFT size, so both have the same bin width and noise levels compare
    directly. Returns the plotted traces (for axis limits) and the number of
    FFTs averaged.
    """
    in_segment  = FFT_SEGMENT_INPUTS
    out_segment = FFT_SEGMENT_INPUTS // 2

    power_in, averages = averaged_fft_power(inputs, in_segment)
    traces = [to_dbfs(power_in, in_segment, 2 ** (config.input_width - 1))]
    ax.plot(np.fft.rfftfreq(in_segment), traces[0], color=COLOUR_INPUT, linewidth=1.5,
            label="Input (data_i)")

    if len(outputs) >= out_segment:
        power_out, _ = averaged_fft_power(outputs, out_segment)
        traces.append(to_dbfs(power_out, out_segment, 2 ** (config.output_width - 1)))
        ax.plot(np.fft.rfftfreq(out_segment, d=2.0), traces[-1], color=COLOUR_OUTPUT,
                linewidth=1.5, label="Output (data_o)")

    return traces, averages


def finish_spectrum_axes(ax, traces):
    """Output Nyquist marker, full scale at the top, labels and recessive grid."""
    ax.axvline(0.25, color=COLOUR_REFERENCE, linestyle=":", linewidth=1)
    ax.text(0.252, 0.98, "Output Nyquist", transform=ax.get_xaxis_transform(),
            va="top", ha="left", color=COLOUR_REFERENCE, fontsize=8)

    lowest  = min(np.min(t) for t in traces)
    highest = max(np.max(t) for t in traces)
    ax.set_ylim(10.0 * np.floor((lowest - 15.0) / 10.0), max(0.0, highest + 3.0))
    ax.set_xlim(0.0, 0.5)
    ax.set_xlabel("Frequency (cycles per input sample)")
    ax.set_ylabel("Power per FFT bin (dBFS)")
    style_axes(ax)


def style_axes(ax):
    ax.grid(True, alpha=0.3)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)


def save_plot(dut, fig, config, name):
    """Save fig to PLOT_DIR/<filter>_cpi<n>_<name>.png and close it."""
    PLOT_DIR.mkdir(parents=True, exist_ok=True)
    path = PLOT_DIR / f"{config.filter_select}_cpi{config.clocks_per_input}_{name}.png"
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    dut._log.info(f"saved {name} plot to {path}")


def plot_noise_spectra(dut, config, samples, monitor, test_name):
    """
    Save the input and output spectra, and the output spectrum expected from
    the coefficients, to PLOT_DIR/<filter>_cpi<n>_<test_name>_fft.png.
    """
    outputs = [value for _, value in monitor.outputs]
    out_segment = FFT_SEGMENT_INPUTS // 2

    fig, ax = plt.subplots(figsize=(10, 5.5))
    traces, averages = draw_spectra(ax, config, samples, outputs)
    if len(traces) < 2:
        dut._log.warning(f"only {len(outputs)} outputs, too few to plot their spectrum")

    f_exp = np.linspace(0.0, 0.25, 1001)
    expected = expected_output_power(config, samples, out_segment, f_exp)
    ax.plot(f_exp, to_dbfs(expected, out_segment, 2 ** (config.output_width - 1)),
            color=COLOUR_REFERENCE, linestyle="--", linewidth=1.5,
            label="Expected output (from coefficients)")

    finish_spectrum_axes(ax, traces)
    ax.set_title(
        f"{test_name.replace('_', ' ').capitalize()}: {config.filter_select}, "
        f"CLOCKS_PER_INPUT={config.clocks_per_input}, "
        f"{len(samples)} inputs, {len(outputs)} outputs\n"
        f"{FFT_SEGMENT_INPUTS}-point input / {out_segment}-point output Hann FFTs, "
        f"{averages} averaged, 0 dBFS = full-scale sine",
        loc="left", fontsize=10,
    )
    ax.legend(loc="lower left")
    save_plot(dut, fig, config, f"{test_name}_fft")


def two_tone_samples(config, n):
    """
    Equal amplitude sines at TONE_FREQS summing to at most config.amplitude,
    with +/-1 LSB triangular dither added before rounding. Without dither the
    rounding error repeats with the tones' 100 sample period and puts spurs
    of up to about -110 dBFS at multiples of 0.01, including 0.1 where the
    0.4 tone aliases - as large as FIR1A's residual there.
    Returns (amplitude of each tone, unrounded tones, integer samples).
    """
    amplitude = (config.amplitude - 2) // 2  # 2 tones + 1 LSB of dither fit config.amplitude
    t = np.arange(n)
    ideal = sum(amplitude * np.sin(2.0 * np.pi * f * t) for f in TONE_FREQS)
    rng = np.random.default_rng(TONE_SEED)
    dither = rng.uniform(-0.5, 0.5, n) + rng.uniform(-0.5, 0.5, n)
    return amplitude, ideal, np.round(ideal + dither).astype(np.int64)


def alias_frequency(f):
    """Where a tone at f (cycles per input sample) lands after decimating by 2."""
    return abs(f - round(2.0 * f) / 2.0)


def plot_two_tone(dut, config, samples, ideal, amplitude, monitor):
    """
    Save PLOT_DIR/<filter>_cpi<n>_two_tone.png with
      1. the input and output waveforms over TIME_PLOT_INPUTS input samples
      2. the input and output spectra, with the ideal output spectrum (the
         unrounded tones through the unquantised filter) dashed
    Both skip the first FFT_SEGMENT_INPUTS inputs so the filter's start-up
    transient isn't in the spectra.
    """
    outputs = np.array([value for _, value in monitor.outputs], dtype=np.int64)
    settle = FFT_SEGMENT_INPUTS
    out_segment = FFT_SEGMENT_INPUTS // 2
    out_full_scale = 2 ** (config.output_width - 1)

    low, high = TONE_FREQS
    gain_db      = 20.0 * np.log10(np.abs(frequency_response(config, low)[0]))
    rejection_db = -20.0 * np.log10(np.abs(frequency_response(config, high)[0]))
    alias        = alias_frequency(high)
    alias_dbfs   = 20.0 * np.log10(amplitude / out_full_scale) - rejection_db
    group_delay  = (config.taps - 1) / 2

    fig, (ax_time, ax_spec) = plt.subplots(
        2, 1, figsize=(10, 10), gridspec_kw={"height_ratios": [2, 3]}
    )

    # 1. Time domain: output m is the filter output at input sample 2m+1
    shown = slice(settle, settle + TIME_PLOT_INPUTS)
    out_index = 2 * np.arange(len(outputs)) + 1
    in_view = (out_index >= settle) & (out_index < settle + TIME_PLOT_INPUTS)
    ax_time.plot(np.arange(len(samples))[shown], samples[shown], color=COLOUR_INPUT,
                 linewidth=0.8, label="Input (data_i)")
    ax_time.plot(out_index[in_view], outputs[in_view], color=COLOUR_OUTPUT, linewidth=2,
                 label="Output (data_o)")
    ax_time.set_title(
        f"Two tones, {low:g} and {high:g} cycles/sample: {config.filter_select}, "
        f"CLOCKS_PER_INPUT={config.clocks_per_input}\n"
        f"Time domain: the output lags by the filter's {group_delay:g} sample group delay",
        loc="left", fontsize=10,
    )
    ax_time.set_xlabel("Input sample index (output m drawn at input sample 2m+1)")
    ax_time.set_ylabel("Amplitude (LSBs)")
    ax_time.legend(loc="lower right", bbox_to_anchor=(1.0, 1.0), ncol=2, frameon=False)
    style_axes(ax_time)

    # 2. Spectra, after the start-up transient
    traces, averages = draw_spectra(ax_spec, config, samples[settle:], outputs[settle // 2:])
    if len(traces) < 2:
        dut._log.warning(f"only {len(outputs)} outputs, too few to plot their spectrum")

    h = np.asarray(config.coefficients, dtype=np.float64) / 2.0 ** config.shift_right_bits
    ideal_out = np.convolve(ideal, h)[: len(ideal)][1::2]
    ideal_power, _ = averaged_fft_power(ideal_out[settle // 2:], out_segment)
    ax_spec.plot(np.fft.rfftfreq(out_segment, d=2.0),
                 to_dbfs(ideal_power, out_segment, out_full_scale),
                 color=COLOUR_REFERENCE, linestyle="--", linewidth=1.5,
                 label="Ideal output (unquantised)")

    finish_spectrum_axes(ax_spec, traces)

    if len(traces) == 2:
        f_out = np.fft.rfftfreq(out_segment, d=2.0)
        near = np.abs(f_out - alias) <= 2.0 / (2 * out_segment)
        peak = np.max(traces[1][near])
        ax_spec.annotate(f"{high:g} tone residual, aliased to {alias:g}",
                         xy=(alias, peak), xytext=(alias + 0.03, peak + 20.0),
                         color=COLOUR_REFERENCE, fontsize=8,
                         arrowprops={"arrowstyle": "->", "color": COLOUR_REFERENCE})

    ax_spec.set_title(
        f"Spectrum: {low:g} tone passes ({gain_db:+.4f} dB), {high:g} tone rejected by "
        f"{rejection_db:.1f} dB, expected residual at {alias:g} is {alias_dbfs:.1f} dBFS\n"
        f"{FFT_SEGMENT_INPUTS}-point input / {out_segment}-point output Hann FFTs, "
        f"{averages} averaged, 0 dBFS = full-scale sine",
        loc="left", fontsize=10,
    )
    ax_spec.legend(loc="upper center", bbox_to_anchor=(0.5, 0.92))
    save_plot(dut, fig, config, "two_tone")

    dut._log.info(
        f"two tone: {low:g} passes at {gain_db:+.4f} dB, {high:g} rejected by "
        f"{rejection_db:.1f} dB, residual aliased to {alias:g} at {alias_dbfs:.1f} dBFS"
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

    # plot before checking, so the plot is there to review when a check fails
    plot_noise_spectra(dut, config, samples, monitor, "noise_regular")

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

    plot_noise_spectra(dut, config, samples, monitor, "noise_irregular")

    check_outputs(dut, config, monitor, samples)
    check_latency(config, monitor)


@cocotb.test()
async def test_two_tone(dut):
    """
    A passband tone (0.01) plus a stopband tone (0.4). The output should hold
    only the 0.01 tone, with whatever is left of the 0.4 tone aliased to 0.1.
    """
    config = DecimatorConfig(dut)
    await start(dut)

    amplitude, ideal, samples = two_tone_samples(config, STREAM_SAMPLES)

    monitor = StreamMonitor(dut)
    await drive(dut, samples, [config.clocks_per_input] * len(samples))
    await drain(dut, config)
    monitor.stop()

    plot_two_tone(dut, config, samples, ideal, amplitude, monitor)

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
