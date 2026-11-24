"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : Python 3
-------------------------------------------------------------------------------
-- Description
--   Reference model for fir_filter.vhd.
--
--   The model is an *ideal* (double precision, no rounding) direct-form FIR:
--
--       y[n] = ( sum_k  c[k] * x[n-k] ) / 2**SHIFT_RIGHT_BITS
--
--   with x[n] = 0 for n < 0 (the filter starts from reset with an empty
--   delay line). c[0] multiplies the newest sample, matching the transposed
--   structure in the RTL where COEFFICIENTS(0) feeds accum_terms(0)/data_o.
--
--   The result is in units of output LSBs, so (hardware - model) is the
--   hardware quantisation error in LSBs directly. With the current truncating
--   output stage that error should lie in (-1, 0].
--
--   float64 is exact here: 16-bit data x 13-bit coefficients x 15 taps is
--   ~2^33, well inside the 2^53 integer range of a double, and dividing by a
--   power of two is exact.
"""

import numpy as np


def fir_model(x, coefficients, shift_right_bits=0):
    """
    Ideal FIR response to `x`.

    Parameters
    ----------
    x : array_like of int
        Input samples, one per valid input cycle.
    coefficients : array_like of int
        Integer tap weights, in the same order as the VHDL COEFFICIENTS generic.
    shift_right_bits : int
        The SHIFT_RIGHT_BITS generic; output is scaled by 2**-shift_right_bits.

    Returns
    -------
    ndarray of float64, same length as `x`
        Ideal output in output-LSB units (not rounded, not width limited).
    """
    x = np.asarray(x, dtype=np.float64)
    h = np.asarray(coefficients, dtype=np.float64)

    # Full convolution is len(x)+len(h)-1 long; the hardware produces one
    # output per input, so keep the first len(x) terms.
    y = np.convolve(x, h)[: len(x)]

    return y / 2.0 ** shift_right_bits


def max_output_magnitude(input_amplitude, coefficients, shift_right_bits=0):
    """
    Worst-case |y| for inputs bounded by +/-input_amplitude: the input lines up
    with the sign of every coefficient, so |y| = A * sum|c| / 2**shift.
    """
    return input_amplitude * np.sum(np.abs(coefficients)) / 2.0 ** shift_right_bits
