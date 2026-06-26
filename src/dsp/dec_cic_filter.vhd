-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- CIC decimation filter
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vhdl_common;
use vhdl_common.math_utils_pkg.all;

entity dec_cic_filter is
  generic(
    DECIMATION_RATE_R  : positive := 2;
    DIFFERENTIAL_DELAY : positive := 1;
    NUMBER_TAPS_N      : positive := 1;
    INPUT_DATA_W       : positive := 16
  );
  port(
    clk_i   : in  std_logic;
    srst_i  : in  std_logic;
    a_i     : in  signed(INPUT_DATA_W-1 downto 0);
    a_vld_i : in  std_logic := '1';
    b_o     : out signed(INPUT_DATA_W-1 downto 0);
    b_vld_o : out std_logic
  );
end dec_cic_filter;

architecture rtl of dec_cic_filter is

  constant INTEGRATOR_OUT_BITS : positive := INPUT_DATA_W;
  signal integrator_data : signed(INTEGRATOR_OUT_BITS-1 downto 0) := to_signed(0,INTEGRATOR_OUT_BITS);
  signal integrator_vld  : std_logic := '0';

  signal decimate_data : signed(INTEGRATOR_OUT_BITS-1 downto 0) := to_signed(0,INTEGRATOR_OUT_BITS); 
  signal decimate_vld  : std_logic := '0';

  constant COMB_OUT_BITS : positive := INTEGRATOR_OUT_BITS;

  signal comb_data : signed(COMB_OUT_BITS-1 downto 0) := to_signed(0,COMB_OUT_BITS); 
  signal comb_vld  : std_logic := '0';

  constant SHIFT_RIGHT_BITS : natural := COMB_OUT_BITS-INPUT_DATA_W;

begin

  --Integrator stages
  integator_i : entity vhdl_common.integrator
  generic map(
    DIFFERENTIAL_DELAY => DIFFERENTIAL_DELAY,
    NUMBER_TAPS_N      => NUMBER_TAPS_N,
    INPUT_DATA_W       => INPUT_DATA_W,
    OUTPUT_DATA_W      => INPUT_DATA_W
  )port map(
    clk_i   => clk_i,
    srst_i  => srst_i,
    a_i     => a_i,
    a_vld_i => a_vld_i,
    b_o     => integrator_data,
    b_vld_o => integrator_vld
  );

  --DECIMATE
  dec_i : entity vhdl_common.raw_decimator
  generic map(
    DECIMATION_RATE_R => DECIMATION_RATE_R,
    INPUT_DATA_W      => INTEGRATOR_OUT_BITS
  )port map(
    clk_i   => clk_i,
    srst_i  => srst_i,
    a_i     => integrator_data,
    a_vld_i => integrator_vld,
    b_o     => decimate_data,
    b_vld_o => decimate_vld
  );

  -- COMB STAGES
  comb_i : entity vhdl_common.comb_filter
  generic map(
    DIFFERENTIAL_DELAY => DIFFERENTIAL_DELAY,
    NUMBER_TAPS_N      => NUMBER_TAPS_N,
    INPUT_DATA_W       => INTEGRATOR_OUT_BITS,
    OUTPUT_DATA_W      => INTEGRATOR_OUT_BITS
  )port map(
    clk_i   => clk_i,
    srst_i  => srst_i,
    a_i     => decimate_data,
    a_vld_i => decimate_vld,
    b_o     => comb_data,
    b_vld_o => comb_vld
  );

  -- output mapping
  b_o     <= resize(shift_right(comb_data,SHIFT_RIGHT_BITS),INPUT_DATA_W);
  b_vld_o <= comb_vld;    

end rtl;
