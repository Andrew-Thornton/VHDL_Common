-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- Polyphase decimate-by-2 FIR filter with time-shared multipliers
--
-- The filter h (COEFFICIENTS, TAPS long) is split into two polyphase branches
--   even input samples x[2m]   are filtered by the odd  taps h[1], h[3], ...
--   odd  input samples x[2m+1] are filtered by the even taps h[0], h[2], ...
-- and one output is produced for every pair of inputs
--
--   y[m] = sum_k h[2k+1]*x[2m-2k] + sum_k h[2k]*x[2m+1-2k]
--
-- which is the full rate FIR output at input sample 2m+1. The first valid
-- input after reset is sample 0 (even), so the output follows every odd input.
--
-- Multiplier sharing
-- Inputs arrive at most once every CLOCKS_PER_INPUT clocks. Each input only
-- meets the taps of its own branch (at most BRANCH_TAPS = ceil(TAPS/2)), so
-- those products are spread over the clocks before the next input arrives
--
--   MULTIPLIERS = ceil(BRANCH_TAPS / CLOCKS_PER_INPUT)
--   SLOTS       = ceil(BRANCH_TAPS / MULTIPLIERS)  (clocks used per input)
--
-- With an input every CLOCKS_PER_INPUT clocks an output is produced every
-- 2*CLOCKS_PER_INPUT clocks.
--
-- Pipeline, per input
--   clock 0          : vld_i, sample written into its branch delay line
--   clocks 1..SLOTS  : slot s operands selected (branch taps s*MULTIPLIERS+j)
--   +1 clock         : MULTIPLIERS products registered
--   +1 clock         : products summed and accumulated into the branch sum
--   +1 clock         : (odd input only) branch sums added, vld_o asserted
-- so vld_o rises SLOTS+3 clocks after the odd input of each pair.
--
-- The output is truncated, as fir_filter:
--   data_o = resize(shift_right(y, SHIFT_RIGHT_BITS), OUTPUT_DATA_WIDTH)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vhdl_common;
use vhdl_common.math_utils_pkg.all;
use vhdl_common.common_types_pkg.all;
use vhdl_common.fir_filter_pkg.all;

entity polyphase_decimator is
  generic(
    TAPS              : positive := RFSOC_FIR1A_TAPS;
    COEFFICIENT_BITS  : positive := RFSOC_FIR1A_COEF_BITS;
    COEFFICIENTS      : array_signed_t(0 to TAPS-1)(COEFFICIENT_BITS-1 downto 0) := RFSOC_FIR1A_COEF;
    CLOCKS_PER_INPUT  : positive := 4;
    INPUT_DATA_WIDTH  : positive := 16;
    OUTPUT_DATA_WIDTH : positive := 16;
    SHIFT_RIGHT_BITS  : natural  := RFSOC_FIR1A_GAIN_BITS
  );
  port(
    clk_i  : in  std_logic;
    srst_i : in  std_logic;
    data_i : in  signed(INPUT_DATA_WIDTH-1 downto 0);
    vld_i  : in  std_logic;
    data_o : out signed(OUTPUT_DATA_WIDTH-1 downto 0);
    vld_o  : out std_logic
  );
end polyphase_decimator;

architecture rtl of polyphase_decimator is

  -- polyphase branch lengths, odd input samples meet the longer branch
  constant ODD_BRANCH_TAPS  : positive := (TAPS+1)/2;
  constant EVEN_BRANCH_TAPS : natural  := TAPS/2;
  constant BRANCH_TAPS      : positive := ODD_BRANCH_TAPS;

  -- multiplier sharing, PADDED_TAPS rounds the branches up to whole slots
  constant MULTIPLIERS : positive := (BRANCH_TAPS + CLOCKS_PER_INPUT - 1) / CLOCKS_PER_INPUT;
  constant SLOTS       : positive := (BRANCH_TAPS + MULTIPLIERS - 1) / MULTIPLIERS;
  constant PADDED_TAPS : positive := SLOTS * MULTIPLIERS;

  constant MULT_W      : positive := INPUT_DATA_WIDTH + COEFFICIENT_BITS;
  constant ACCUM_WIDTH : positive := MULT_W + ceil_log2(TAPS);

  -- returns every second coefficient starting at first_tap, zero padded to
  -- PADDED_TAPS so every multiplier has a coefficient in every slot
  function polyphase_branch(first_tap : natural) return array_signed_t is
    variable branch : array_signed_t(0 to PADDED_TAPS-1)(COEFFICIENT_BITS-1 downto 0) := (others => (others => '0'));
  begin
    for k in 0 to PADDED_TAPS-1 loop
      if first_tap + 2*k < TAPS then
        branch(k) := COEFFICIENTS(first_tap + 2*k);
      end if;
    end loop;
    return branch;
  end function polyphase_branch;

  constant EVEN_BRANCH_COEF : array_signed_t(0 to PADDED_TAPS-1)(COEFFICIENT_BITS-1 downto 0) := polyphase_branch(1);
  constant ODD_BRANCH_COEF  : array_signed_t(0 to PADDED_TAPS-1)(COEFFICIENT_BITS-1 downto 0) := polyphase_branch(0);

  -- branch delay lines, newest sample at index 0
  -- entries beyond the branch length are never written and stay zero
  signal even_samples : array_signed_t(0 to PADDED_TAPS-1)(INPUT_DATA_WIDTH-1 downto 0) := (others => (others => '0'));
  signal odd_samples  : array_signed_t(0 to PADDED_TAPS-1)(INPUT_DATA_WIDTH-1 downto 0) := (others => (others => '0'));
  signal in_phase     : std_logic := '0';

  -- slot sequencer
  signal seq_active : std_logic := '0';
  signal seq_slot   : natural range 0 to SLOTS-1 := 0;
  signal seq_phase  : std_logic := '0';

  -- stage 1, selected operands
  signal sel_vld   : std_logic := '0';
  signal sel_first : std_logic := '0';
  signal sel_last  : std_logic := '0';
  signal sel_phase : std_logic := '0';
  signal sel_coef  : array_signed_t(0 to MULTIPLIERS-1)(COEFFICIENT_BITS-1 downto 0) := (others => (others => '0'));
  signal sel_data  : array_signed_t(0 to MULTIPLIERS-1)(INPUT_DATA_WIDTH-1 downto 0) := (others => (others => '0'));

  -- stage 2, products
  signal mult_vld   : std_logic := '0';
  signal mult_first : std_logic := '0';
  signal mult_last  : std_logic := '0';
  signal mult_phase : std_logic := '0';
  signal mult_terms : array_signed_t(0 to MULTIPLIERS-1)(MULT_W-1 downto 0) := (others => (others => '0'));

  -- stage 3, branch sums
  signal accum    : signed(ACCUM_WIDTH-1 downto 0) := (others => '0');
  signal even_sum : signed(ACCUM_WIDTH-1 downto 0) := (others => '0');
  signal odd_sum  : signed(ACCUM_WIDTH-1 downto 0) := (others => '0');
  signal sums_vld : std_logic := '0';

  -- stage 4, output
  signal result     : signed(ACCUM_WIDTH-1 downto 0) := (others => '0');
  signal result_vld : std_logic := '0';

begin

  -- Writes each valid input into its polyphase branch delay line, newest
  -- sample at index 0, alternating between the even and odd branches
  p_delay_lines : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if vld_i = '1' then
        if in_phase = '0' then
          even_samples(0) <= data_i;
          for k in 1 to EVEN_BRANCH_TAPS-1 loop
            even_samples(k) <= even_samples(k-1);
          end loop;
        else
          odd_samples(0) <= data_i;
          for k in 1 to ODD_BRANCH_TAPS-1 loop
            odd_samples(k) <= odd_samples(k-1);
          end loop;
        end if;
        in_phase <= not in_phase;
      end if;
      if srst_i = '1' then
        even_samples <= (others => (others => '0'));
        odd_samples  <= (others => (others => '0'));
        in_phase     <= '0';
      end if;
    end if;
  end process p_delay_lines;

  -- Steps through the SLOTS multiplier slots for the branch of the latest
  -- input, starting the clock after it arrives. A new input may arrive on
  -- the last slot of the previous one, as it is written to the other branch
  p_sequencer : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if vld_i = '1' then
        seq_active <= '1';
        seq_slot   <= 0;
        seq_phase  <= in_phase;
      elsif seq_active = '1' then
        if seq_slot = SLOTS-1 then
          seq_active <= '0';
        else
          seq_slot <= seq_slot + 1;
        end if;
      end if;

      assert srst_i = '1' or vld_i /= '1' or seq_active = '0' or seq_slot = SLOTS-1
        report "polyphase_decimator: vld_i arrived before the previous input was processed, " &
               "inputs must be at least CLOCKS_PER_INPUT clocks apart"
        severity error;

      if srst_i = '1' then
        seq_active <= '0';
        seq_slot   <= 0;
        seq_phase  <= '0';
      end if;
    end if;
  end process p_sequencer;

  -- Selects the coefficient and sample for each multiplier in the current
  -- slot, multiplier j handles branch tap seq_slot*MULTIPLIERS + j
  p_select : process(clk_i)
    variable tap : natural range 0 to PADDED_TAPS-1;
  begin
    if rising_edge(clk_i) then
      sel_vld   <= seq_active;
      sel_phase <= seq_phase;
      if seq_slot = 0 then
        sel_first <= '1';
      else
        sel_first <= '0';
      end if;
      if seq_slot = SLOTS-1 then
        sel_last <= '1';
      else
        sel_last <= '0';
      end if;
      for j in 0 to MULTIPLIERS-1 loop
        tap := seq_slot*MULTIPLIERS + j;
        if seq_phase = '0' then
          sel_coef(j) <= EVEN_BRANCH_COEF(tap);
          sel_data(j) <= even_samples(tap);
        else
          sel_coef(j) <= ODD_BRANCH_COEF(tap);
          sel_data(j) <= odd_samples(tap);
        end if;
      end loop;
      if srst_i = '1' then
        sel_vld <= '0';
      end if;
    end if;
  end process p_select;

  -- Multiplies each selected sample by its coefficient, MULTIPLIERS
  -- multipliers each used once per slot
  p_multiply : process(clk_i)
  begin
    if rising_edge(clk_i) then
      mult_vld   <= sel_vld;
      mult_first <= sel_first;
      mult_last  <= sel_last;
      mult_phase <= sel_phase;
      for j in 0 to MULTIPLIERS-1 loop
        mult_terms(j) <= sel_data(j) * sel_coef(j);
      end loop;
      if srst_i = '1' then
        mult_vld <= '0';
      end if;
    end if;
  end process p_multiply;

  -- Sums each slot's products and accumulates them over the SLOTS slots,
  -- then stores the finished sum for the even or odd branch. An odd branch
  -- sum completes an output pair
  p_accumulate : process(clk_i)
    variable slot_sum   : signed(ACCUM_WIDTH-1 downto 0);
    variable branch_sum : signed(ACCUM_WIDTH-1 downto 0);
  begin
    if rising_edge(clk_i) then
      sums_vld <= '0';
      if mult_vld = '1' then
        slot_sum := (others => '0');
        for j in 0 to MULTIPLIERS-1 loop
          slot_sum := slot_sum + resize(mult_terms(j), ACCUM_WIDTH);
        end loop;
        if mult_first = '1' then
          branch_sum := slot_sum;
        else
          branch_sum := accum + slot_sum;
        end if;
        accum <= branch_sum;
        if mult_last = '1' then
          if mult_phase = '0' then
            even_sum <= branch_sum;
          else
            odd_sum  <= branch_sum;
            sums_vld <= '1';
          end if;
        end if;
      end if;
      if srst_i = '1' then
        sums_vld <= '0';
        accum    <= (others => '0');
        even_sum <= (others => '0');
        odd_sum  <= (others => '0');
      end if;
    end if;
  end process p_accumulate;

  -- Adds the even and odd branch sums to form each decimated output
  p_output : process(clk_i)
  begin
    if rising_edge(clk_i) then
      result_vld <= sums_vld;
      if sums_vld = '1' then
        result <= even_sum + odd_sum;
      end if;
      if srst_i = '1' then
        result_vld <= '0';
        result     <= (others => '0');
      end if;
    end if;
  end process p_output;

  -- currently a truncation rounding method depending on the generics
  data_o <= resize(shift_right(result, SHIFT_RIGHT_BITS), OUTPUT_DATA_WIDTH);
  vld_o  <= result_vld;

end rtl;
