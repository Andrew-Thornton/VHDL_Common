-------------------------------------------------------------------------------
-- This code is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This code is provided WITHOUT ANY WARRANTY; 
-- without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
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

entity not_gate is
  port(
    clk_i  : in  std_logic;
    srst_i : in  std_logic;
    a_i    : in  std_logic;
    b_o    : out std_logic
  );
end not_gate;

architecture rtl of not_gate is

begin

  main_proc : process(clk_i)
  begin
    if rising_edge(clk_i) then
      b_o <= not(a_i);
      if srst_i = '1' then
        b_o <= '0';
      end if;
    end if;
  end process main_proc;

end rtl;