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
-- Creation Date : 2023-Dec-09
-- Standard      : VDHL 2008
-------------------------------------------------------------------------------
-- Rev  Author        Description
-- 1.0  A. Thornton   Testbench Creation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.common_float_tools_pkg.all;

entity float_add_tb is
end float_add_tb;

architecture test_bench of float_add_tb is

  component float_add is
    port(
      clk_i  : in  std_logic;
      srst_i : in  std_logic;
      a_i    : in  std_logic_vector(31 downto 0);
      b_i    : in  std_logic_vector(31 downto 0);
      c_o    : out std_logic_vector(31 downto 0)
    );
  end component float_add;
  
  constant CLOCK_FREQ_MHZ : real := 1.0;
  constant CLOCK_PERIOD   : time := (1.0/CLOCK_FREQ_MHZ) * 1.0 us;
  constant CLOCK_HOLD     : time := CLOCK_PERIOD/10.0;
  
  -- tb clock and reset
  signal tb_clk    : std_logic := '0';
  signal tb_srst   : std_logic := '1';
  
  --tb inputs
  signal tb_a      : std_logic_vector(31 downto 0);
  signal tb_b      : std_logic_vector(31 downto 0);
  
  --tb outputs
  signal tb_c      : std_logic_vector(31 downto 0);

begin

  dut : float_add
  port map(
    clk_i  => tb_clk,
    srst_i => tb_srst,
    a_i    => tb_a,
    b_i    => tb_b,
    c_o    => tb_c
  );

  tb_clock_proc : process
  begin
    tb_clk <= not(tb_clk);
    wait for CLOCK_PERIOD/2;
  end process tb_clock_proc;
  
  tb_reset_proc : process
  begin
    tb_srst <= '1';
    wait for 9*CLOCK_PERIOD;
    wait until rising_edge(tb_clk);
    tb_srst <= '0';
    wait;
  end process tb_reset_proc;

  -- this process checks all 4 possible combinations for the and gate
  -- and ensures the correct values are output.
  tb_main_proc : process
  begin
    --tb_a <= "00111110001000000000000000000000"; -- +0.15625
    --tb_b <= "00111110101000000000000000000000"; -- +0.3125
    tb_a <= real_to_slv(0.15625);
    tb_b <= real_to_slv(0.3125);
    
    wait;
  
  end process tb_main_proc;

end test_bench;