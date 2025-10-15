-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Creation Date : 2023-Dec-08
-- Standard      : VDHL 2008
-------------------------------------------------------------------------------
-- Rev  Author        Description
-- 1.0  A. Thornton   Module Creation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity or_gate is
  port(
    clk_i  : in  std_logic;
    srst_i : in  std_logic;
    a_i    : in  std_logic;
    b_i    : in  std_logic;
    c_o    : out std_logic
  );
end or_gate;

architecture rtl of or_gate is

begin

  main_proc : process(clk_i)
  begin
    if rising_edge(clk_i) then
      c_o <= a_i or b_i;
      if srst_i = '1' then
        c_o <= '0';
      end if;
    end if;
  end process main_proc;

end rtl;