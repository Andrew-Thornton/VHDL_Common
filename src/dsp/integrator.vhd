-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- Integrator, originally designed for a cascade integrate comb filter
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_utils_pkg.all;

entity integrator is
  generic(
    DIFFERENTIAL_DELAY : positive := 1;
    NUMBER_TAPS_N      : positive := 1;
    INPUT_DATA_W       : positive := 16;
    OUTPUT_DATA_W      : positive := 16
  );
  port(
    clk_i   : in  std_logic;
    srst_i  : in  std_logic;
    a_i     : in  signed(INPUT_DATA_W-1 downto 0);
    a_vld_i : in  std_logic := '1';
    b_o     : out signed(OUTPUT_DATA_W-1 downto 0);
    b_vld_o : out std_logic
  );
end integrator;

architecture rtl of integrator is

  type signed_array_t is array (natural range <>) of signed;
  signal tap_signal : signed_array_t(0 to NUMBER_TAPS_N)(OUTPUT_DATA_W-1 downto 0) := (others => (others => '0'));
  signal tap_vld    : std_logic_vector(0 to NUMBER_TAPS_N) := (others => '0');

begin

  -- input mapping
  tap_signal(0) <= resize(a_i,OUTPUT_DATA_W);
  tap_vld(0)    <= a_vld_i;

  tap_generator_g : for tap in 0 to NUMBER_TAPS_N-1 generate

    -- Intermediate signal sized to this stage's actual output width
    signal stage_out : signed(INPUT_DATA_W + tap downto 0);  -- width = INPUT_DATA_W+tap+1

  begin
    
    my_tap_i : entity work.integrator_stage 
    generic map(
      DIFFERENTIAL_DELAY => DIFFERENTIAL_DELAY,
      INPUT_DATA_W       => INPUT_DATA_W + tap        -- input width for this stage
    )
    port map(
      clk_i   => clk_i,
      srst_i  => srst_i,
      a_i     => resize(tap_signal(tap), INPUT_DATA_W + tap),  -- narrow to stage input width
      a_vld_i => tap_vld(tap),
      b_o     => stage_out,                                     -- stage output (INPUT_DATA_W+tap+1 bits)
      b_vld_o => tap_vld(tap + 1)
    );

    -- allow for wrap around
    tap_signal(tap + 1) <= stage_out(OUTPUT_DATA_W-1 downto 0);

  end generate tap_generator_g;

  -- Output mapping
  b_o     <= tap_signal(NUMBER_TAPS_N);
  b_vld_o <= tap_vld(NUMBER_TAPS_N);

end rtl;




