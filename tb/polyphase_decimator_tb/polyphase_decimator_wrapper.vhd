-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- Testbench wrapper for polyphase_decimator
--
-- Selects a PG269 coefficient set from fir_filter_pkg by name (FILTER_SELECT
-- is "FIR1A", "FIR2" or "FIR3") with the matching unity DC gain shift. Array
-- generics cannot be set from the simulator command line, so this lets the
-- pytest runner choose the coefficient set with a string generic.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vhdl_common;
use vhdl_common.common_types_pkg.all;
use vhdl_common.fir_filter_pkg.all;

entity polyphase_decimator_wrapper is
  generic(
    FILTER_SELECT     : string   := "FIR1A";
    CLOCKS_PER_INPUT  : positive := 4;
    INPUT_DATA_WIDTH  : positive := 16;
    OUTPUT_DATA_WIDTH : positive := 16
  );
  port(
    clk_i  : in  std_logic;
    srst_i : in  std_logic;
    data_i : in  signed(INPUT_DATA_WIDTH-1 downto 0);
    vld_i  : in  std_logic;
    data_o : out signed(OUTPUT_DATA_WIDTH-1 downto 0);
    vld_o  : out std_logic
  );
end polyphase_decimator_wrapper;

architecture tb of polyphase_decimator_wrapper is

  function select_taps(name : string) return positive is
  begin
    if name = "FIR1A" then
      return RFSOC_FIR1A_TAPS;
    elsif name = "FIR2" then
      return RFSOC_FIR2_TAPS;
    elsif name = "FIR3" then
      return RFSOC_FIR3_TAPS;
    end if;
    report "polyphase_decimator_wrapper: unknown FILTER_SELECT " & name severity failure;
    return 1;
  end function select_taps;

  function select_coef_bits(name : string) return positive is
  begin
    if name = "FIR1A" then
      return RFSOC_FIR1A_COEF_BITS;
    elsif name = "FIR2" then
      return RFSOC_FIR2_COEF_BITS;
    end if;
    return RFSOC_FIR3_COEF_BITS;
  end function select_coef_bits;

  function select_coefficients(name : string) return array_signed_t is
  begin
    if name = "FIR1A" then
      return RFSOC_FIR1A_COEF;
    elsif name = "FIR2" then
      return RFSOC_FIR2_COEF;
    end if;
    return RFSOC_FIR3_COEF;
  end function select_coefficients;

  function select_gain_bits(name : string) return natural is
  begin
    if name = "FIR1A" then
      return RFSOC_FIR1A_GAIN_BITS;
    elsif name = "FIR2" then
      return RFSOC_FIR2_GAIN_BITS;
    end if;
    return RFSOC_FIR3_GAIN_BITS;
  end function select_gain_bits;

  constant TAPS             : positive := select_taps(FILTER_SELECT);
  constant COEFFICIENT_BITS : positive := select_coef_bits(FILTER_SELECT);
  constant COEFFICIENTS     : array_signed_t(0 to TAPS-1)(COEFFICIENT_BITS-1 downto 0) := select_coefficients(FILTER_SELECT);
  constant SHIFT_RIGHT_BITS : natural  := select_gain_bits(FILTER_SELECT);

begin

  -- Decimator under test, configured with the selected coefficient set
  -- and its unity DC gain output shift
  dut_i : entity vhdl_common.polyphase_decimator
  generic map(
    TAPS              => TAPS,
    COEFFICIENT_BITS  => COEFFICIENT_BITS,
    COEFFICIENTS      => COEFFICIENTS,
    CLOCKS_PER_INPUT  => CLOCKS_PER_INPUT,
    INPUT_DATA_WIDTH  => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
    SHIFT_RIGHT_BITS  => SHIFT_RIGHT_BITS
  )port map(
    clk_i  => clk_i,
    srst_i => srst_i,
    data_i => data_i,
    vld_i  => vld_i,
    data_o => data_o,
    vld_o  => vld_o
  );

end tb;
