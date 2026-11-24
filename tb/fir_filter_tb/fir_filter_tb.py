"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : cocotb / Python 3
-------------------------------------------------------------------------------
-- Description
--   cocotb testbench for the fir filter entity.
--
--
--   Strategy
--   --------
--   TBD
"""
 
import math
import itertools
from pathlib import Path
 
import numpy as np
import matplotlib
matplotlib.use("Agg")  # headless backend: simulations rarely have a display
import matplotlib.pyplot as plt
 
import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotb.types import LogicArray

from fir_filter_model import fir_model, max_output_magnitude

CLOCK_PERIOD_NS = 10
CLOCK_HOLD_NS = 1
 
# Noise test settings
NOISE_SAMPLES   = 16384              # number of input samples and captured output samples
NOISE_AMPLITUDE = 16000             # peak amplitude in LSBs (clamped to INPUT_DATA_WIDTH)
NOISE_SEED      = 12345             # fixed seed so runs are repeatable
NOISE_CSV       = "noise_test_io.csv"
NOISE_PLOT      = "noise_test_fft.png"

# Model comparison test settings
MODEL_SAMPLES       = 16384
MODEL_AMPLITUDE     = 16000         # requested peak input; reduced if the output could overflow
MODEL_SEED          = 54321
MODEL_MAX_ERROR_LSB = 2             # fail if |hardware - model| exceeds this anywhere
MODEL_ZOOM_SAMPLES  = 200           # samples shown in the time-domain overlay
MODEL_CSV           = "model_comparison.csv"
MODEL_PLOT          = "model_comparison.png"

# Plot colours (validated categorical pair + neutral inks)
COLOUR_MODEL     = "#257de0"
COLOUR_HARDWARE  = "#f47230"
COLOUR_REFERENCE = "#666666"

 
def initialise(dut):
    TAPS = dut.TAPS.value
    COEFFICIENT_BITS = dut.COEFFICIENT_BITS.value
    INPUT_DATA_WIDTH = dut.INPUT_DATA_WIDTH.value
    OUTPUT_DATA_WIDTH = dut.OUTPUT_DATA_WIDTH.value
 
    dut.data_i.value = 0
    dut.vld_i.value = 0
 
 
 
 
async def assert_reset(dut):
    dut.srst_i.value = 1
 
    await ClockCycles(dut.clk_i, 10, RisingEdge)
    dut.srst_i.value = 0
 
 
async def sine_driver(dut, amplitude, fnorm, cycles):
 
    for n in range(cycles):
 
        # Generate sine wave sample
        sample = amplitude * math.sin(2.0 * math.pi * fnorm * n)
 
        # Quantise to integer
        sample = int(round(sample))
 
        # Drive input
        dut.data_i.value = sample
        dut.vld_i.value = 1
 
        # Wait for next rising clock edge
        await RisingEdge(dut.clk_i)
 
    # Deassert valid after final sample
    dut.vld_i.value = 0
    dut.data_i.value = 0
 
 
@cocotb.test()
async def sine_wave_test(dut):
 
    dut._log.info("=== Starting sine wave test ===")
    dut._log.info("=== initialising inputs ===")
    initialise(dut)
 
 
    dut._log.info("=== starting clock ===")
 
    my_clk = Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns")
    my_clk.start(start_high=False)
 
    dut._log.info("=== clock started ===")
 
    dut._log.info("=== starting reset ===")
    await assert_reset(dut)
    dut._log.info("=== reset complete===")
 
    amplitude = 16000
    fnorm = 0.01
    cycles = 10000
 
    dut._log.info("=== staring input driver of a sine wave ===")
    input_driver = cocotb.start_soon(sine_driver(dut, amplitude, fnorm, cycles))
 
    dut._log.info(f"=== awaiting  {cycles} cycles===")
 
    await input_driver
 
    dut._log.info("=== test complete===")
 
 
async def noise_driver(dut, samples):
    """Drive one sample per clock, with vld_i held high for the whole burst."""
 
    for sample in samples:
        dut.data_i.value = int(sample)
        dut.vld_i.value = 1
        await RisingEdge(dut.clk_i)
 
    # Deassert valid after final sample
    dut.vld_i.value = 0
    dut.data_i.value = 0
 
 
async def output_monitor(dut, n_samples, timeout_cycles=100):
    """
    Capture data_o on every rising edge where vld_o is high until n_samples
    have been collected. Fails if they don't all arrive within
    n_samples + timeout_cycles clocks (e.g. vld_o never asserts).
    """
 
    captured = []
 
    for _ in range(n_samples + timeout_cycles):
        await RisingEdge(dut.clk_i)
 
        if dut.vld_o.value == 1:
            captured.append(dut.data_o.value.to_signed())
            if len(captured) == n_samples:
                break
 
    assert len(captured) == n_samples, (
        f"Only captured {len(captured)} of {n_samples} output samples"
    )
 
    return np.array(captured, dtype=np.int64)
 
 
def plot_noise_spectra(input_samples, output_samples, path):
    """FFT the input and output and save a comparison plot to `path`."""
 
    n = len(input_samples)
    freqs = np.fft.rfftfreq(n, d=1.0)           # cycles/sample (same units as fnorm)
 
    x_fft = np.fft.rfft(input_samples)
    y_fft = np.fft.rfft(output_samples)
 
    eps = 1e-12                                  # avoid log(0)
    x_db = 20.0 * np.log10(np.abs(x_fft) / n + eps)
    y_db = 20.0 * np.log10(np.abs(y_fft) / n + eps)
 
    # Since Y(f) = H(f) * X(f) for an LTI filter, the ratio estimates the
    # filter's frequency response (white noise excites every bin).
    h_db = 20.0 * np.log10((np.abs(y_fft) + eps) / (np.abs(x_fft) + eps))
 
    fig, (ax_spec, ax_resp) = plt.subplots(2, 1, sharex=True, figsize=(10, 8))
 
    ax_spec.plot(freqs, x_db, label="Input",  alpha=0.6, linewidth=0.8)
    ax_spec.plot(freqs, y_db, label="Output", alpha=0.6, linewidth=0.8)
    ax_spec.set_ylabel("Magnitude (dB, rel. 1 LSB)")
    ax_spec.set_title(f"Uniform noise through FIR filter ({n} samples)")
    ax_spec.grid(True, alpha=0.3)
    ax_spec.legend()
 
    ax_resp.plot(freqs, h_db, color="tab:green", linewidth=0.8)
    ax_resp.set_xlabel("Normalised frequency (cycles/sample)")
    ax_resp.set_ylabel("|Y| / |X| (dB)")
    ax_resp.set_title("Output / input (estimated frequency response)")
    ax_resp.grid(True, alpha=0.3)
 
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
 
 
@cocotb.test()
async def noise_test(dut):
 
    dut._log.info("=== Starting noise test ===")
    dut._log.info("=== initialising inputs ===")
    initialise(dut)
 
    dut._log.info("=== starting clock ===")
    my_clk = Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns")
    my_clk.start(start_high=False)
 
    dut._log.info("=== starting reset ===")
    await assert_reset(dut)
    dut._log.info("=== reset complete===")
 
    # Uniform integer noise in [-amplitude, +amplitude], clamped to the input width
    max_amplitude = 2 ** (int(dut.INPUT_DATA_WIDTH.value) - 1) - 1
    amplitude = min(NOISE_AMPLITUDE, max_amplitude)
 
    rng = np.random.default_rng(NOISE_SEED)
    input_samples = rng.integers(-amplitude, amplitude, size=NOISE_SAMPLES, endpoint=True)
 
    dut._log.info(f"=== driving {NOISE_SAMPLES} samples of uniform noise (+/-{amplitude}) ===")
 
    # Start the monitor first so no output sample can be missed
    monitor = cocotb.start_soon(output_monitor(dut, NOISE_SAMPLES))
    driver = cocotb.start_soon(noise_driver(dut, input_samples))
 
    await driver
    output_samples = await monitor
 
    dut._log.info(f"=== captured {len(output_samples)} output samples ===")
 
    # Save input/output pairs
    csv_path = Path(NOISE_CSV).resolve()
    np.savetxt(
        csv_path,
        np.column_stack((np.arange(NOISE_SAMPLES), input_samples, output_samples)),
        fmt="%d",
        delimiter=",",
        header="index,input,output",
        comments="",
    )
    dut._log.info(f"=== saved samples to {csv_path} ===")
 
    # FFT and compare
    plot_path = Path(NOISE_PLOT).resolve()
    plot_noise_spectra(input_samples, output_samples, plot_path)
    dut._log.info(f"=== saved FFT comparison plot to {plot_path} ===")
 
    # Minimal sanity checks (no pass/fail criteria on the filter response yet)
    assert len(output_samples) == NOISE_SAMPLES
    assert np.any(output_samples != 0), "Filter output is all zeros"

    dut._log.info("=== test complete===")


def read_coefficients(dut):
    """Read the COEFFICIENTS generic back from the DUT as a list of signed ints."""
    return [int(c.to_signed()) for c in dut.COEFFICIENTS.value]


def plot_model_comparison(hw_output, model_output, tolerance, zoom_samples, path):
    """
    Save a three-panel comparison of the hardware against the model:
      1. time-domain overlay of the first `zoom_samples` outputs
      2. error (hardware - model) per sample, with the +/- tolerance limits
      3. histogram of the error
    """

    error = hw_output - model_output
    n = len(hw_output)
    idx = np.arange(n)
    zoom = slice(0, min(zoom_samples, n))

    fig, (ax_time, ax_err, ax_hist) = plt.subplots(
        3, 1, figsize=(10, 10), gridspec_kw={"height_ratios": [3, 2, 2]}
    )

    # 1. Overlay - the two traces should sit on top of each other
    ax_time.plot(idx[zoom], model_output[zoom], color=COLOUR_MODEL, linewidth=2,
                 label="Python model (ideal)")
    ax_time.plot(idx[zoom], hw_output[zoom], color=COLOUR_HARDWARE, linestyle="none",
                 marker="o", markersize=3, label="Hardware (data_o)")
    ax_time.set_title(f"Hardware vs model, first {zoom.stop} of {n} samples", loc="left")
    ax_time.set_xlabel("Output sample index")
    ax_time.set_ylabel("Output (LSBs)")
    ax_time.legend(loc="lower right", bbox_to_anchor=(1.0, 1.0), ncol=2, frameon=False)

    # 2. Error against sample index
    ax_err.plot(idx, error, color=COLOUR_MODEL, linewidth=0.6)
    for limit in (-tolerance, tolerance):
        ax_err.axhline(limit, color=COLOUR_REFERENCE, linestyle="--", linewidth=1)
    ax_err.text(n, tolerance, f"  +{tolerance} LSB limit", va="center", ha="left",
                color=COLOUR_REFERENCE, fontsize=8)
    ax_err.text(n, -tolerance, f"  -{tolerance} LSB limit", va="center", ha="left",
                color=COLOUR_REFERENCE, fontsize=8)
    span = max(tolerance + 0.5, np.max(np.abs(error)) * 1.1)
    ax_err.set_ylim(-span, span)
    ax_err.set_xlim(0, n)
    ax_err.set_title(
        f"Error (hardware - model): max |e| = {np.max(np.abs(error)):.3f} LSB, "
        f"mean = {np.mean(error):.3f} LSB, rms = {np.sqrt(np.mean(error**2)):.3f} LSB"
    )
    ax_err.set_xlabel("Output sample index")
    ax_err.set_ylabel("Error (LSBs)")

    # 3. Error distribution
    # Fixed-width bins: error values are multiples of 2**-SHIFT_RIGHT_BITS, so
    # an automatic bin count aliases against them and leaves empty bins.
    bin_width = 0.05
    bins = np.arange(-span, span + bin_width, bin_width)
    ax_hist.hist(error, bins=bins, color=COLOUR_MODEL, edgecolor="white", linewidth=0.5)
    for limit in (-tolerance, tolerance):
        ax_hist.axvline(limit, color=COLOUR_REFERENCE, linestyle="--", linewidth=1)
    ax_hist.set_xlim(-span, span)
    ax_hist.set_title("Error distribution")
    ax_hist.set_xlabel("Error (LSBs)")
    ax_hist.set_ylabel("Samples")

    for ax in (ax_time, ax_err, ax_hist):
        ax.grid(True, alpha=0.3)
        for side in ("top", "right"):
            ax.spines[side].set_visible(False)

    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


@cocotb.test()
async def model_comparison_test(dut):
    """
    Drive uniform noise through the DUT, run the same samples through the
    Python model, and fail if any output differs from the model by more than
    MODEL_MAX_ERROR_LSB.
    """

    dut._log.info("=== Starting model comparison test ===")
    dut._log.info("=== initialising inputs ===")
    initialise(dut)

    dut._log.info("=== starting clock ===")
    my_clk = Clock(dut.clk_i, CLOCK_PERIOD_NS, unit="ns")
    my_clk.start(start_high=False)

    dut._log.info("=== starting reset ===")
    await assert_reset(dut)
    dut._log.info("=== reset complete===")

    # Model parameters come straight from the DUT generics so they can't drift
    coefficients = read_coefficients(dut)
    shift_right_bits = int(dut.SHIFT_RIGHT_BITS.value)
    input_width = int(dut.INPUT_DATA_WIDTH.value)
    output_width = int(dut.OUTPUT_DATA_WIDTH.value)
    dut._log.info(f"=== coefficients {coefficients}, shift right {shift_right_bits} ===")

    # Keep the stimulus inside the input range, and small enough that the
    # worst-case output cannot overflow data_o. Overflow is a range problem,
    # not a filter error, so it shouldn't be measured by this test.
    max_input = 2 ** (input_width - 1) - 1
    max_output = 2 ** (output_width - 1) - 1
    gain = max_output_magnitude(1, coefficients, shift_right_bits)
    amplitude = int(min(MODEL_AMPLITUDE, max_input, max_output // gain))
    if amplitude < MODEL_AMPLITUDE:
        dut._log.warning(
            f"=== input amplitude reduced from {MODEL_AMPLITUDE} to {amplitude} "
            f"to avoid overflowing the {output_width}-bit output ==="
        )

    rng = np.random.default_rng(MODEL_SEED)
    input_samples = rng.integers(-amplitude, amplitude, size=MODEL_SAMPLES, endpoint=True)

    dut._log.info(f"=== driving {MODEL_SAMPLES} samples of uniform noise (+/-{amplitude}) ===")

    monitor = cocotb.start_soon(output_monitor(dut, MODEL_SAMPLES))
    driver = cocotb.start_soon(noise_driver(dut, input_samples))

    await driver
    hw_output = (await monitor).astype(np.float64)

    model_output = fir_model(input_samples, coefficients, shift_right_bits)
    error = hw_output - model_output
    abs_error = np.abs(error)

    dut._log.info(
        f"=== error vs model: max |e| = {abs_error.max():.3f} LSB, "
        f"mean = {error.mean():.3f} LSB, rms = {np.sqrt(np.mean(error**2)):.3f} LSB ==="
    )

    # Save results before checking, so they're available when the test fails
    csv_path = Path(MODEL_CSV).resolve()
    np.savetxt(
        csv_path,
        np.column_stack((np.arange(MODEL_SAMPLES), input_samples, hw_output, model_output, error)),
        fmt=["%d", "%d", "%d", "%.6f", "%.6f"],
        delimiter=",",
        header="index,input,hw_output,model_output,error",
        comments="",
    )
    dut._log.info(f"=== saved samples to {csv_path} ===")

    plot_path = Path(MODEL_PLOT).resolve()
    plot_model_comparison(hw_output, model_output, MODEL_MAX_ERROR_LSB, MODEL_ZOOM_SAMPLES, plot_path)
    dut._log.info(f"=== saved model comparison plot to {plot_path} ===")

    failures = np.flatnonzero(abs_error > MODEL_MAX_ERROR_LSB)
    if len(failures) > 0:
        for i in failures[:10]:
            dut._log.error(
                f"sample {i}: hardware {hw_output[i]:.0f}, model {model_output[i]:.3f}, "
                f"error {error[i]:+.3f} LSB"
            )
    assert len(failures) == 0, (
        f"{len(failures)} of {MODEL_SAMPLES} samples exceed the {MODEL_MAX_ERROR_LSB} LSB "
        f"error limit (max |e| = {abs_error.max():.3f} LSB, first at sample {failures[0]})"
    )

    dut._log.info("=== test complete===")
 