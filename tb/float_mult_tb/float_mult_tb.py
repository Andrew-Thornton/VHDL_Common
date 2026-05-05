"""
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : cocotb / Python 3
-------------------------------------------------------------------------------
-- Rev  Author       Date        Description
-- 1.0  A. Thornton  cocotb      Cross-matrix testbench for float_mult
-------------------------------------------------------------------------------
-- Description
--   cocotb testbench for the float_mult entity.
--
--   The DUT is a 6-stage pipeline so every stimulus applied at cycle N
--   produces a result at cycle N+6.
--
--   Strategy
--   --------
--   A representative set of IEEE-754 single-precision values is defined that
--   covers every interesting category:
--
--       Normal positives  (several magnitudes)
--       Normal negatives
--       +/- Zero
--       +/- Infinity
--       NaN
--       Subnormal
--
--   Every (a, b) ordered pair in that set is applied back-to-back on
--   consecutive rising edges to keep the pipeline fully occupied.  Once all
--   stimuli have been driven the outputs are checked in the same order,
--   PIPELINE_DEPTH cycles after each input was applied.
--
--   Expected values are computed by Python's own IEEE-754 float arithmetic
--   (via the struct module) so no hand-coded reference table is needed.
--
--   Tolerance
--   ---------
--   For normal results a 1-ULP tolerance is accepted to account for any
--   rounding difference between the DUT and Python.  Special-value results
--   (NaN, Inf, zero) are checked categorically rather than bit-exactly.
-------------------------------------------------------------------------------
"""

import math
import struct
import itertools

import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PIPELINE_DEPTH = 6      # DUT latency in clock cycles
ULP_TOLERANCE  = 1      # Acceptable difference in raw bit patterns for normals


# ---------------------------------------------------------------------------
# IEEE-754 helpers
# ---------------------------------------------------------------------------

def f2b(f: float) -> int:
    """Python float → IEEE-754 single-precision bit pattern (uint32)."""
    return struct.unpack(">I", struct.pack(">f", f))[0]


def b2f(bits: int) -> float:
    """IEEE-754 single-precision bit pattern (uint32) → Python float."""
    return struct.unpack(">f", struct.pack(">I", int(bits) & 0xFFFF_FFFF))[0]


def is_nan_bits(b: int) -> bool:
    return ((b >> 23) & 0xFF) == 0xFF and (b & 0x7F_FFFF) != 0


def is_inf_bits(b: int) -> bool:
    return ((b >> 23) & 0xFF) == 0xFF and (b & 0x7F_FFFF) == 0


def is_zero_bits(b: int) -> bool:
    return (b & 0x7FFF_FFFF) == 0


def category(b: int) -> str:
    """Human-readable category for a bit pattern."""
    if is_nan_bits(b):  return "NaN"
    if is_inf_bits(b):  return f"{'+'if not(b>>31) else '-'}Inf"
    if is_zero_bits(b): return f"{'+'if not(b>>31) else '-'}Zero"
    return f"{b2f(b):.6g}"


# ---------------------------------------------------------------------------
# Stimulus set – one entry per interesting IEEE-754 category / magnitude
# ---------------------------------------------------------------------------

# Smallest positive subnormal
_SUBNORM_POS = struct.unpack(">I", struct.pack(">I", 0x0000_0001))[0]
_SUBNORM_NEG = struct.unpack(">I", struct.pack(">I", 0x8000_0001))[0]

STIMULUS_BITS: list[int] = [
    # Normal positives
    f2b(1.0),
    f2b(2.0),
    f2b(0.5),
    f2b(1234.5678),
    f2b(1.17549435e-38),    # smallest normal positive
    f2b(3.4028235e+38),     # largest normal positive (MAX_FLOAT)

    # Normal negatives
    f2b(-1.0),
    f2b(-2.0),
    f2b(-1234.5678),

    # Zeros
    f2b(+0.0),
    f2b(-0.0),

    # Infinities
    0x7F80_0000,            # +Inf
    0xFF80_0000,            # -Inf

    # NaN (quiet)
    0x7FC0_0000,

    # Subnormals
    _SUBNORM_POS,
    _SUBNORM_NEG,
]


# ---------------------------------------------------------------------------
# Expected-result helper
# ---------------------------------------------------------------------------

def expected_result(a_bits: int, b_bits: int):
    """
    Return (category_str, expected_bits_or_None).

    For special results only the category is meaningful; expected_bits is None.
    For normal results expected_bits holds Python's rounded result.
    """
    a_nan  = is_nan_bits(a_bits)
    b_nan  = is_nan_bits(b_bits)
    a_inf  = is_inf_bits(a_bits)
    b_inf  = is_inf_bits(b_bits)
    a_zero = is_zero_bits(a_bits)
    b_zero = is_zero_bits(b_bits)

    # Any NaN in → NaN out
    if a_nan or b_nan:
        return "NaN", None

    # Inf * 0 or 0 * Inf → NaN
    if (a_inf and b_zero) or (a_zero and b_inf):
        return "NaN", None

    # Inf * non-zero finite → Inf (sign from XOR of signs)
    if a_inf or b_inf:
        sign = ((a_bits >> 31) ^ (b_bits >> 31)) & 1
        return "Inf", None

    # 0 * anything finite → 0
    if a_zero or b_zero:
        return "Zero", None

    # Normal / subnormal – use Python arithmetic
    a_f = b2f(a_bits)
    b_f = b2f(b_bits)
    r_f = a_f * b_f

    if math.isinf(r_f):
        return "Inf", None
    if math.isnan(r_f):
        return "NaN", None
    if r_f == 0.0:
        return "Zero", None

    return "normal", f2b(r_f)


# ---------------------------------------------------------------------------
# Initialisation coroutine
# ---------------------------------------------------------------------------

async def initialise(dut):
    """Start clock, assert synchronous reset, flush pipeline."""
    dut._log.info("=== initialise: starting clock and reset ===")

    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())

    dut.srst_i.value = 1
    dut.a_i.value    = 0
    dut.b_i.value    = 0

    # Hold reset for several cycles
    await ClockCycles(dut.clk_i, 8)

    # De-assert on a rising edge, then wait for pipeline to drain
    await RisingEdge(dut.clk_i)
    dut.srst_i.value = 0
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH + 2)

    dut._log.info("=== initialise: complete ===")


# ---------------------------------------------------------------------------
# Main test
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_float_mult_cross_matrix(dut):
    """
    Apply every ordered (a, b) pair from STIMULUS_BITS to the DUT
    back-to-back, then verify each output PIPELINE_DEPTH cycles after
    its corresponding input was driven.
    """
    await initialise(dut)

    # Build the full ordered cross-product list
    pairs = list(itertools.product(STIMULUS_BITS, repeat=2))
    n     = len(pairs)

    dut._log.info(
        f"Cross-matrix: {len(STIMULUS_BITS)} values × {len(STIMULUS_BITS)} values "
        f"= {n} test vectors"
    )

    # ------------------------------------------------------------------
    # Phase 1 – drive all stimuli on consecutive rising edges
    # ------------------------------------------------------------------
    for a_bits, b_bits in pairs:
        await RisingEdge(dut.clk_i)
        dut.a_i.value = a_bits
        dut.b_i.value = b_bits

    # ------------------------------------------------------------------
    # Phase 2 – let the last transaction propagate through the pipeline
    # ------------------------------------------------------------------
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH)

    # ------------------------------------------------------------------
    # Phase 3 – replay stimulus order, reading output one cycle per pair
    # ------------------------------------------------------------------
    # The first result appears PIPELINE_DEPTH cycles after the first input,
    # i.e. we are already positioned correctly after Phase 2.
    # We step back one rising edge per result (they arrive every cycle).

    # Re-drive inputs during checking (keeps pipeline busy but we only care
    # about the output window that corresponds to our original stimulus).
    # Easiest: just read on the cycle boundary each time.
    #
    # Because we drove N inputs on N consecutive edges, and then waited
    # PIPELINE_DEPTH more edges, result[0] appeared exactly at the END of
    # Phase 2.  We sample result[0] NOW, then clock once per remaining result.

    pass_count  = 0
    fail_count  = 0
    skip_count  = 0     # special-value results checked categorically

    for idx, (a_bits, b_bits) in enumerate(pairs):

        result_bits = int(dut.c_o.value)
        cat, exp_bits = expected_result(a_bits, b_bits)

        label = (
            f"[{idx+1:>4}/{n}] "
            f"a={category(a_bits):>14}  "
            f"b={category(b_bits):>14}  →  "
        )

        if cat == "NaN":
            ok = is_nan_bits(result_bits)
            verdict = "PASS" if ok else "FAIL"
            dut._log.info(f"{label}expect NaN   got {category(result_bits)}  {verdict}")
            if ok: pass_count  += 1
            else:  fail_count  += 1; assert False, f"{label}expected NaN, got 0x{result_bits:08X}"

        elif cat == "Inf":
            ok = is_inf_bits(result_bits)
            verdict = "PASS" if ok else "FAIL"
            dut._log.info(f"{label}expect Inf   got {category(result_bits)}  {verdict}")
            if ok: pass_count  += 1
            else:  fail_count  += 1; assert False, f"{label}expected Inf, got 0x{result_bits:08X}"

        elif cat == "Zero":
            ok = is_zero_bits(result_bits)
            verdict = "PASS" if ok else "FAIL"
            dut._log.info(f"{label}expect Zero  got {category(result_bits)}  {verdict}")
            if ok: pass_count  += 1
            else:  fail_count  += 1; assert False, f"{label}expected Zero, got 0x{result_bits:08X}"

        else:   # normal result – check within 1 ULP
            diff = abs(result_bits - exp_bits)
            ok   = diff <= ULP_TOLERANCE
            verdict = "PASS" if ok else "FAIL"
            dut._log.info(
                f"{label}"
                f"expect 0x{exp_bits:08X}({b2f(exp_bits):.6g})  "
                f"got 0x{result_bits:08X}({b2f(result_bits):.6g})  "
                f"Δ={diff}  {verdict}"
            )
            if ok: pass_count += 1
            else:
                fail_count += 1
                assert False, (
                    f"{label}MISMATCH  "
                    f"expected 0x{exp_bits:08X} ({b2f(exp_bits)}), "
                    f"got 0x{result_bits:08X} ({b2f(result_bits)}), "
                    f"Δ={diff} ULP"
                )

        # Advance to the next output (unless this is the last one)
        if idx < n - 1:
            await RisingEdge(dut.clk_i)

    # Drain pipeline before simulation ends
    await ClockCycles(dut.clk_i, PIPELINE_DEPTH + 2)

    dut._log.info(
        f"=== Cross-matrix complete: {pass_count} PASS  "
        f"{fail_count} FAIL  {skip_count} SKIP  "
        f"(total {n}) ==="
    )