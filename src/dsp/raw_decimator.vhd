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

use work.math_utils_pkg.all;

entity raw_decimator is
  generic(
    DECIMATION_RATE_R  : positive := 2;
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
end raw_decimator;

architecture rtl of raw_decimator is

  constant COUNTER_BITS : positive := ceil_log2(DECIMATION_RATE_R);
  signal cntr : unsigned(COUNTER_BITS-1 downto 0) := (others => '0');

  signal result  : signed(INPUT_DATA_W-1 downto 0) := (others => '0');
  signal res_vld : std_logic := '0';

begin

  decimate_p : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      res_vld <= '0';
      if a_vld_i = '1' then
        if cntr = 0 then
          cntr    <= to_unsigned(DECIMATION_RATE_R-1,COUNTER_BITS);
          result  <= a_i;
          res_vld <= '1';
        else
          cntr <= cntr-1;
        end if;
      end if;
      if srst_i = '1' then
        res_vld <= '0';
        cntr    <= (others => '0');
        result  <= (others => '0');
      end if;
    end if;
  end process;

  b_o     <= result;
  b_vld_o <= res_vld;

end rtl;