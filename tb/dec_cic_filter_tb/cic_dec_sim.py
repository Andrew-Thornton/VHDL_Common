import csv

import numpy as np
import matplotlib.pyplot as plt


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
    if _return_parts == True:
        print("HELLO")
        for i in range(10):
            print(f"x[{i}] : {x[i]}")

    # Quantise input to int16 (clamp then cast)
    x = np.clip(
        np.round(np.asarray(x, dtype=np.float64)), -32768, 32767
    ).astype(np.int16)

    if _return_parts == True:
        for i in range(10):
            print(f"x[{i}] : {x[i]}")

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
            if i < 10 and _return_parts==True:
                print(f"i       : {i}  ,  stage : {stage}")
                print(f"comb[i - delay] : {comb[i - delay]}")
                print(f"comb[i]         : {comb[i]}")
                print(f'delayed : {delayed}')
                print(f'np.int32(comb[i]) - delayed : {np.int32(comb[i]) - delayed}')
                print(f'out[i]  : {out[i]}\n')

        comb = out

        if _return_parts:
            parts[f"comb_{stage + 1}"] = comb.copy()

    if _return_parts:
        parts["output"] = comb.copy()
        return comb, parts

    return comb


def export_parts_csv(
    freq,
    n_stages=3,
    delay=1,
    signal_length=512,
    filename="cic_parts.csv",
):
    """
    Run the CIC decimator for a single normalised input frequency and write
    every intermediate stage signal to a CSV file.

    Each column holds one signal stage.  Because the integrator stages run at
    the input sample rate while the decimated/comb stages run at half that
    rate, shorter columns are padded with empty cells so all columns share the
    same number of rows.

    Parameters
    ----------
    freq : float
        Normalised input frequency in [0, 0.5)  (cycles per input sample).
    n_stages : int
        Number of integrator / comb stages (N).
    delay : int
        Comb differential delay (M).
    signal_length : int
        Number of *input* samples to simulate.
    filename : str
        Output CSV path.

    Returns
    -------
    filename : str
        Path of the written CSV file.
    """

    # Generate sinusoidal test signal scaled to full int16 range
    n = np.arange(signal_length)
    x = np.round(32767 * np.sin(2 * np.pi * freq * n)).astype(np.int16)

    # Run filter, collecting all intermediate stages
    _, parts = cic_decimate_by_2(
        x,
        n_stages=n_stages,
        delay=delay,
        _return_parts=True,
    )

    # Build an ordered list of (column_name, array) pairs
    # Order: input, integrator_1…N, decimated, comb_1…N, output
    columns = []
    columns.append(("input", parts["input"]))
    for s in range(1, n_stages + 1):
        columns.append((f"integrator_{s}", parts[f"integrator_{s}"]))
    columns.append(("decimated", parts["decimated"]))
    for s in range(1, n_stages + 1):
        columns.append((f"comb_{s}", parts[f"comb_{s}"]))
    columns.append(("output", parts["output"]))

    # Pad shorter arrays with empty strings so every row is complete
    max_len = max(len(arr) for _, arr in columns)

    with open(filename, "w", newline="") as f:
        writer = csv.writer(f)

        # Header row
        writer.writerow([name for name, _ in columns])

        # Data rows
        for row_idx in range(max_len):
            row = []
            for _, arr in columns:
                if row_idx < len(arr):
                    row.append(int(arr[row_idx]))
                else:
                    row.append("")   # pad with blank for shorter columns
            writer.writerow(row)

    print(
        f"Wrote {max_len} rows × {len(columns)} columns  →  {filename}\n"
        f"  freq={freq}, N={n_stages}, M={delay}, "
        f"input_len={signal_length}"
    )
    return filename


def measure_frequency_response(
    n_stages=3,
    delay=1,
    n_freqs=400,
    signal_length=8192
):
    """
    Numerically measure CIC response by sweeping sinusoids
    """

    freqs = np.linspace(0.0, 0.5, n_freqs)
    magnitude_db = np.zeros_like(freqs)

    n = np.arange(signal_length)

    for k, f in enumerate(freqs):

        if f == 0:
            magnitude_db[k] = 0
            continue

        # Generate sinusoid scaled to full int16 range
        x = np.round(32767 * np.sin(2 * np.pi * f * n)).astype(np.int16)

        # Filter
        y = cic_decimate_by_2(
            x,
            n_stages=n_stages,
            delay=delay
        )

        # Remove startup transient
        settle = len(y) // 4
        y_ss = y[settle:].astype(np.float64)

        # Measure amplitude (normalise back to ±1 scale)
        amplitude = np.sqrt(2) * np.std(y_ss) / 32767

        magnitude_db[k] = 20 * np.log10(
            amplitude + 1e-12
        )

    return freqs, magnitude_db


def main():

    N = 1     # CIC order
    M = 2     # differential delay

    freqs, mag_db = measure_frequency_response(
        n_stages=N,
        delay=M
    )

    plt.figure(figsize=(10, 5))
    plt.plot(freqs, mag_db)

    plt.title(f"CIC Decimate-by-2 Frequency Response (N={N}, M={M})")
    plt.xlabel("Input Frequency (Fs_in)")
    plt.ylabel("Magnitude (dB)")
    plt.grid(True)

    plt.xlim(0, 0.5)
    plt.ylim(-120, 5)

    plt.show()

    # Export all intermediate stages for a 0.1 Fs_in tone
    export_parts_csv(
        freq=0.001,
        n_stages=N,
        delay=M,
        signal_length=512,
        filename="cic_parts.csv",
    )


if __name__ == "__main__":
    main()