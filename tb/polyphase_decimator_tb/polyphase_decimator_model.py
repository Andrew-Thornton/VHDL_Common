"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : Python 3
-------------------------------------------------------------------------------
-- Description
--   Reference model for polyphase_decimator.vhd.
--
--   The model is deliberately *not* polyphase: it runs the full rate FIR and
--   keeps every second output, then applies the same truncating shift as the
--   RTL
--
--       y[m] = floor( (h * x)[2m+1] / 2**SHIFT_RIGHT_BITS )
--
--   with x[n] = 0 for n < 0. Output m is the FIR output at the odd input
--   sample 2m+1, matching the RTL which outputs after each odd input.
--
--   Integers are exact in int64: 16 bit data x 18 bit coefficients x 59 taps
--   is ~2^40, and >> on a numpy int64 is an arithmetic (floor) shift like
--   numeric_std shift_right on a signed.
--
--   The resource and timing helpers mirror the constants in the RTL.
"""

import numpy as np


def polyphase_decimator_model(x, coefficients, shift_right_bits):
    """
    Bit-exact decimate-by-2 output for input samples `x`.

    Returns an int64 array of len(x)//2 outputs, in output LSBs, assuming the
    result fits the output width (see safe_amplitude).
    """
    x = np.asarray(x, dtype=np.int64)
    h = np.asarray(coefficients, dtype=np.int64)

    full_rate = np.convolve(x, h)[: len(x)]
    return full_rate[1::2] >> shift_right_bits


def branch_taps(taps):
    """Length of the longer polyphase branch, ceil(TAPS/2)."""
    return (taps + 1) // 2


def multipliers(taps, clocks_per_input):
    """Multipliers the RTL instantiates, ceil(ceil(TAPS/2) / CLOCKS_PER_INPUT)."""
    return -(-branch_taps(taps) // clocks_per_input)


def slots(taps, clocks_per_input):
    """Clocks the RTL spends issuing products for each input."""
    return -(-branch_taps(taps) // multipliers(taps, clocks_per_input))


def latency_clocks(taps, clocks_per_input):
    """Clocks from the odd input of a pair being registered to vld_o rising."""
    return slots(taps, clocks_per_input) + 3


def safe_amplitude(coefficients, shift_right_bits, input_width, output_width):
    """
    Largest input amplitude A for which no output can overflow: the worst case
    input lines up with the sign of every coefficient, |y| = A*sum|h|/2**shift.
    """
    input_max = 2 ** (input_width - 1) - 1
    output_max = 2 ** (output_width - 1) - 1
    gain = np.sum(np.abs(coefficients)) / 2.0 ** shift_right_bits
    return int(min(input_max, np.floor(output_max / gain)))
