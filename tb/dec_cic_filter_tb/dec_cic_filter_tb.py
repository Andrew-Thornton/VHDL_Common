"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : cocotb / Python 3
-------------------------------------------------------------------------------
-- Description
--   cocotb testbench for the CIC decimation filter.
--
--   Sweeps a sine wave across normalised frequencies 0.0 to 0.5 in steps of
--   0.05, measures the output RMS power at each frequency, and prints a
--   frequency-response table.
-------------------------------------------------------------------------------
"""

import math
import numpy as np
import matplotlib.pyplot as plt
import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CLOCK_PERIOD_NS = 10


def _wrap16(x):
    """
    Cast an integer value or ndarray to int16 with two's-complement wraparound.

    Arithmetic is kept in int32 to avoid numpy's undefined overflow behaviour
    on signed integer dtypes.  This masks to 16 bits and reinterprets the
    result as a signed 16-bit value, exactly as a hardware register does.
    """
    return (((np.asarray(x, dtype=np.int32) + 0x8000) & 0xFFFF) - 0x8000).astype(np.int16)

def cic_decimate_by_2(x, n_stages=1, delay=1, _return_parts=False):
    """
    First-principles CIC decimator by 2 using int16 arithmetic with
    two's-complement wraparound at every stage.

    All internal accumulation and differencing is performed in int16.
    Overflow wraps silently, mirroring fixed-point hardware behaviour.
    The output is NOT gain-normalised (division would leave the int16 domain;
    scale externally if needed).

    Parameters
    ----------
    x : array_like
        Input samples.  Floating-point values are rounded and clamped to
        the int16 range [-32768, 32767] on entry.
    n_stages : int
        Number of integrator/comb stages (N).
    delay : int
        Comb differential delay (M).
    _return_parts : bool
        If True, return a dict of all intermediate stage signals
        in addition to the final output.

    Returns
    -------
    y : ndarray of int16
        Decimated output (always returned).
    parts : dict  (only when _return_parts=True)
        Keys:
          'input'                           – int16 input signal
          'integrator_1' … 'integrator_N'  – int16 output of each integrator
          'decimated'                       – int16 signal after downsample x2
          'comb_1' … 'comb_N'              – int16 output of each comb stage
          'output'                          – same as the last comb stage
        Integrator/input arrays are at the input sample rate;
        decimated/comb/output arrays are at half that rate.
    """

    # Quantise input to int16 (clamp then cast)
    x = np.clip(
        np.round(np.asarray(x, dtype=np.float64)), -32768, 32767
    ).astype(np.int16)

    parts = {"input": x.copy()} if _return_parts else {}

    # ------------------------------------------------------------
    # Integrator section  –  acc = (acc + x[n]) mod 2^16
    # All arithmetic promoted to int32 so wrap is explicit via _wrap16.
    # ------------------------------------------------------------
    integ = x.copy()

    for stage in range(n_stages):
        running_sum = np.zeros(len(integ), dtype=np.int16)

        for i in range(len(integ)):
            prev = np.int32(running_sum[i - delay]) if i >= delay else np.int32(0)
            running_sum[i] = _wrap16(np.int32(integ[i]) + prev)

        integ = running_sum

        if _return_parts:
            parts[f"integrator_{stage + 1}"] = integ.copy()

    # ------------------------------------------------------------
    # Decimate by 2  –  keep every other sample (no arithmetic, no wrap)
    # ------------------------------------------------------------
    decimated = integ[::2].copy()

    if _return_parts:
        parts["decimated"] = decimated.copy()

    # ------------------------------------------------------------
    # Comb section  –  y[n] = (x[n] - x[n-M]) mod 2^16
    # ------------------------------------------------------------
    comb = decimated.copy()

    for stage in range(n_stages):
        out = np.zeros(len(comb), dtype=np.int16)

        for i in range(len(comb)):
            delayed = np.int32(comb[i - delay]) if i >= delay else np.int32(0)
            out[i] = _wrap16(np.int32(comb[i]) - delayed)
            # if i < 10 and _return_parts==True:
            #     print(f"i       : {i}  ,  stage : {stage}")
            #     print(f"comb[i - delay] : {comb[i - delay]}")
            #     print(f"comb[i]         : {comb[i]}")
            #     print(f'delayed : {delayed}')
            #     print(f'np.int32(comb[i]) - delayed : {np.int32(comb[i]) - delayed}')
            #     print(f'out[i]  : {out[i]}\n')

        comb = out

        if _return_parts:
            parts[f"comb_{stage + 1}"] = comb.copy()

    if _return_parts:
        parts["output"] = comb.copy()
        return comb, parts

    return comb


def get_sim_output(dut, f_norm, samples_input):
    input_bit_width = dut.INPUT_DATA_W.value
    decimation_rate = dut.DECIMATION_RATE_R.value
    n_taps = dut.NUMBER_TAPS_N.value
    dut_delay = dut.DIFFERENTIAL_DELAY.value

    max_value=(2**(input_bit_width-1))-1
    n = np.arange(samples_input)
    x = np.round(max_value * np.sin(2 * np.pi * f_norm * n)).astype(np.int16)
    assert decimation_rate == 2

    sim_values = cic_decimate_by_2(x, n_taps, dut_delay, _return_parts=False)
    return sim_values

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
    await ClockCycles(dut.clk_i, 10)

    dut._log.info("=== initialise: complete ===")


# ---------------------------------------------------------------------------
# Input driver coroutine
# ---------------------------------------------------------------------------

async def sine_inputter(dut, number_samples, norm_freq, bit_width):
    """
    Drive a_i with a sine wave over number_samples clock cycles.

    Args:
        dut:            cocotb DUT handle
        number_samples: number of samples to drive
        norm_freq:      normalised frequency (0.0 <= norm_freq < 0.5),
                        expressed as a fraction of the sample rate.
                        e.g. 0.1 => sine completes one cycle every 10 samples
        bit_width:      bit width of a_i (signed two's-complement).
                        e.g. 16 => range [-32768, 32767]
    """
    max_val = (2**(bit_width-1)) - 1   # e.g.  32767 for 16-bit

    for counter in range(number_samples):
        sine_float = math.sin(2.0 * math.pi * norm_freq * counter)
        sine_int   = int(round(sine_float * max_val))
        dut.a_i.value     = sine_int
        dut.a_vld_i.value = 1
        await RisingEdge(dut.clk_i)

    # De-assert valid after the burst
    dut.a_vld_i.value = 0


# ---------------------------------------------------------------------------
# Output power measurement coroutine
# ---------------------------------------------------------------------------

async def output_collect(dut, number_samples):
    """
    Collect number_samples valid output samples from b_o / b_vld_o

    The result is returned so the caller can retrieve it after
    awaiting this coroutine (cocotb tasks cannot return values directly).

    Args:
        dut:            cocotb DUT handle
        number_samples: how many valid output samples to collect
    """
    samples = []

    while len(samples) < number_samples:
        await RisingEdge(dut.clk_i)
        if dut.b_vld_o.value == 1:
            samples.append(int(dut.b_o.value.to_signed()))

    # store output samples
    return samples

# ---------------------------------------------------------------------------
# Main test
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_cic_decimator_across_frequencies(dut):
    """
    Sweep input sine frequency from 0.0 to 0.50 in steps of 0.05 and
    measure the output RMS power at each frequency to characterise the
    filter's frequency response.
    """
    input_bit_width = dut.INPUT_DATA_W.value
    decimation_rate = dut.DECIMATION_RATE_R.value
    n_taps = dut.NUMBER_TAPS_N.value

    # Full-scale peak amplitude for normalisation
    full_scale = (1 << (input_bit_width - 1)) - 1

    # Number of complete sine cycles to drive at every frequency.
    # Using a whole number of cycles ensures the measurement window starts
    # and ends at the same phase, eliminating spectral leakage from the
    # RMS estimate.
    NUM_CYCLES = 30

    norm_freqs    = []
    output_powers = []

    # for freq in np.arange(0.1, 0.2, 0.1):
    for freq in np.arange(0.001, 0.501, 0.001):

        # Samples per cycle at this frequency, rounded to the nearest integer
        # so we always drive an exact whole number of periods.
        number_samples = round(NUM_CYCLES / freq)

        await initialise(dut)

        # Shared result container — tasks cannot return values directly
        output_values = [None] * math.floor(number_samples / decimation_rate)

        # Start input driver and output measurement concurrently
        input_task  = cocotb.start_soon(
            sine_inputter(dut, number_samples, freq, input_bit_width)
        )
        #CLAUDE please change this to extract the output power
        output_task = cocotb.start_soon(
            output_collect(dut, math.floor(number_samples / decimation_rate))
        )
        #claude please calculate power_result here

        # Wait for both to complete
        await input_task
        output_values = await output_task

        #CLAUDE PLEASE add in a cic_decimate_by_2 where the outputs are collected

        norm_freqs.append(freq)
        rms_power = math.sqrt(sum(s * s for s in output_values) / len(output_values))
        # Normalise RMS power to [0.0, 1.0] relative to full-scale amplitude
        normalised_power = rms_power / full_scale
        output_powers.append(normalised_power)

        dut._log.info(
            f"freq={freq:.3f}  samples={number_samples}"
            f"  output_rms_power={rms_power:.3f}"
            f"  normalised={normalised_power:.4f}"
            f"  number_samples={number_samples}"
        )

        numpy_output_values = np.array(output_values, dtype=np.int16)
        #Run the simulation and get the output
        sim_output_values = get_sim_output(dut, freq, number_samples)

        tol = 1

        for i, (sim, ref) in enumerate(zip(sim_output_values, numpy_output_values)):
            diff = abs(int(sim) - int(ref))
            assert diff <= tol, (
                f"Mismatch at index {i}: sim={sim}, ref={ref}, diff={diff}"
            )

    # Print frequency-response table
    dut._log.info("===== Frequency Response Table =====")
    print("\n===== CIC Decimator Frequency Response =====")
    print(f"{'Norm Freq':>12}  {'Norm RMS Power':>14}")
    print("-" * 30)
    for f, p in zip(norm_freqs, output_powers):
        print(f"  {f:>10.3f}  {p:>14.4f}")
    print("=" * 30)
    # Plot frequency response
    # Convert to dB, guarding against zero power (log of zero is undefined)
    output_powers_db = [
        20 * math.log10(p) if p > 0 else -math.inf
        for p in output_powers
    ]

    fig, (ax_lin, ax_db) = plt.subplots(2, 1, figsize=(9, 7))
    fig.suptitle(
        f"CIC Decimator Frequency Response\n"
        f"(R={decimation_rate}, {input_bit_width}-bit input)",
        fontsize=13
    )

    # Linear plot
    ax_lin.plot(norm_freqs, output_powers, color="steelblue", linewidth=1.5)
    ax_lin.set_xlabel("Normalised Frequency (x Fs)")
    ax_lin.set_ylabel("Normalised RMS Power")
    ax_lin.set_xlim(0, max(norm_freqs))
    ax_lin.set_ylim(bottom=0)
    ax_lin.grid(True, linestyle="--", alpha=0.5)
    ax_lin.set_title("Linear Scale")

    # dB plot
    ax_db.plot(norm_freqs, output_powers_db, color="darkorange", linewidth=1.5)
    ax_db.set_xlabel("Normalised Frequency (x Fs)")
    ax_db.set_ylabel("Normalised RMS Power (dB)")
    ax_db.set_xlim(0, max(norm_freqs))
    ax_db.grid(True, linestyle="--", alpha=0.5)
    ax_db.set_title("dB Scale")

    plt.tight_layout()
    plot_path = f'./cic_freq_response_{n_taps}_taps.png'
    plt.savefig(plot_path, dpi=150)
    plt.close(fig)
    dut._log.info(f"Frequency response plot saved to {plot_path}")