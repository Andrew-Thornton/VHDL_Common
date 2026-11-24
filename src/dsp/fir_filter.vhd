-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- Basic FIR filter
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vhdl_common;
use vhdl_common.math_utils_pkg.all;
use vhdl_common.common_types_pkg.all;
use vhdl_common.fir_filter_pkg.all;

entity fir_filter is
  generic(
    TAPS              : positive := RFSOC_FIR3_TAPS;
    COEFFICIENT_BITS  : positive := RFSOC_FIR3_COEF_BITS;
    COEFFICIENTS      : array_signed_t(0 to TAPS-1)(COEFFICIENT_BITS-1 downto 0) := RFSOC_FIR3_COEF;
    INPUT_DATA_WIDTH  : positive := 16;
    OUTPUT_DATA_WIDTH : positive := 16;
    SHIFT_RIGHT_BITS  : natural  := 0
  );
  port(
    clk_i   : in  std_logic;
    srst_i  : in  std_logic;
    data_i  : in  signed(INPUT_DATA_WIDTH-1 downto 0);
    vld_i   : in  std_logic := '1';
    data_o  : out signed(OUTPUT_DATA_WIDTH-1 downto 0);
    vld_o   : out std_logic
  );
end fir_filter;

architecture rtl of fir_filter is

  constant ACCUM_WIDTH : natural := INPUT_DATA_WIDTH+COEFFICIENT_BITS+ ceil_log2(TAPS);
  signal accum_terms : array_signed_t(0 to TAPS-1)(ACCUM_WIDTH-1 downto 0) := (others => (others =>'0'));
  signal dbg_mult_terms : array_signed_t(0 to TAPS-1)(INPUT_DATA_WIDTH+COEFFICIENT_BITS-1 downto 0) := (others => (others =>'0'));
  signal dbg_coef: array_signed_t(0 to TAPS-1)(COEFFICIENT_BITS-1 downto 0) := (others => (others =>'0'));

  signal vld_z : std_logic := '0';

begin

  -- The following is a transpose fir filter
  -- it passes the input data to all the taps
  -- then sums up a series of mult and add lines
  -- multipliers are removed if 
  p_transpose_fir : process(clk_i)
    constant MULT_W : natural := INPUT_DATA_WIDTH+COEFFICIENT_BITS;
    variable mult_terms : array_signed_t(0 to TAPS-1)(MULT_W-1 downto 0);
  begin
    if rising_edge(clk_i) then
      vld_z <= vld_i;
      if vld_i = '1' then
        for tap in 0 to TAPS-1 loop
          dbg_coef(tap) <= COEFFICIENTS(tap);
          if tap = TAPS-1 then
            if COEFFICIENTS(tap) /= to_signed(0,COEFFICIENT_BITS) then
              mult_terms(tap) := data_i * COEFFICIENTS(tap);
              -- dbg_mult_terms(tap) <= data_i * COEFFICIENTS(tap);
              dbg_mult_terms(tap) <= (others => '1');
              accum_terms(tap) <= resize(mult_terms(tap), ACCUM_WIDTH);
            else
              -- mult by zero means no multiplier required and this term is zero
              dbg_mult_terms(tap) <= (others => '1');
              accum_terms(tap) <= (others => '0');
            end if;
          else
            if COEFFICIENTS(tap) /= to_signed(0,COEFFICIENT_BITS) then
              mult_terms(tap) := data_i * COEFFICIENTS(tap);
              dbg_mult_terms(tap) <= data_i * COEFFICIENTS(tap);

              -- dbg_mult_terms(tap) <= (others => '1');
              accum_terms(tap) <= mult_terms(tap) + accum_terms(tap+1);
            else
              -- mult by zero means this term is just the previous term
              mult_terms(tap) := (others => '0');
              dbg_mult_terms(tap) <= (others => '0');
              accum_terms(tap) <= accum_terms(tap+1);
            end if;
          end if;
        end loop;
      end if;
      if srst_i = '1' then
        accum_terms <= (others => (others => '0'));
      end if;
    end if;
  end process;

  -- currently a truncation rounding method depending on the generics
  data_o <= resize(shift_right(accum_terms(0),SHIFT_RIGHT_BITS),OUTPUT_DATA_WIDTH);
  vld_o <= vld_z;

end rtl;
