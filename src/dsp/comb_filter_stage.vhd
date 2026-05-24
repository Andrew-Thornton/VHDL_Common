-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- Comb Filter
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity comb_filter_stage is
  generic(
    DIFFERENTIAL_DELAY : positive := 1;
    INPUT_DATA_W       : positive := 16
  );
  port(
    clk_i   : in  std_logic;
    srst_i  : in  std_logic;
    a_i     : in  signed(INPUT_DATA_W-1 downto 0);
    a_vld_i : in  std_logic := '1';
    b_o     : out signed(INPUT_DATA_W downto 0);
    b_vld_o : out std_logic
  );
end comb_filter_stage;
architecture rtl of comb_filter_stage is

  type signed_array_t is array (natural range <>) of signed;
  -- Delay line holds DIFFERENTIAL_DELAY samples: index 1 to DIFFERENTIAL_DELAY
  signal a_delay : signed_array_t(1 to DIFFERENTIAL_DELAY)(INPUT_DATA_W-1 downto 0)
                   := (others => (others => '0'));
  signal vld_delay : std_logic := '0';

  signal result : signed(INPUT_DATA_W downto 0) := (others => '0');

begin

  comb_p : process(clk_i)
    variable a_i_se          : signed(INPUT_DATA_W downto 0);
    variable a_last_delay_se : signed(INPUT_DATA_W downto 0);
  begin
    if rising_edge(clk_i) then
      -- delay line
      a_delay <= a_delay;
      vld_delay <= a_vld_i;
      if a_vld_i = '1' then
        a_delay(1) <= a_i;
        if DIFFERENTIAL_DELAY > 1 then
          a_delay(2 to DIFFERENTIAL_DELAY) <= a_delay(1 to DIFFERENTIAL_DELAY-1);
        end if;
        -- comb
        a_i_se          := resize(a_i, INPUT_DATA_W+1);
        a_last_delay_se := resize(a_delay(DIFFERENTIAL_DELAY), INPUT_DATA_W+1);
        result          <= a_i_se - a_last_delay_se;
      end if;

      if srst_i = '1' then
        vld_delay <= '0';
        result    <= (others => '0');
        a_delay   <= (others => (others => '0'));
      end if;
    end if;
  end process;

  b_o     <= result;
  b_vld_o <= vld_delay;

end rtl;