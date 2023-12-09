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
-- Creation Date : 2023-Dec-23
-------------------------------------------------------------------------------
-- Rev  Author        Description
-- 1.0  A. Thornton   Testbench Creation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nand_gate_tb is
end nand_gate_tb;

architecture test_bench of nand_gate_tb is

  component nand_gate is
    port(
      clk_i  : in  std_logic;
      srst_i : in  std_logic;
      a_i    : in  std_logic;
      b_i    : in  std_logic;
      c_o    : out std_logic
    );
  end component nand_gate;
  
  constant CLOCK_FREQ_MHZ : real := 1.0;
  constant CLOCK_PERIOD   : time := (1.0/CLOCK_FREQ_MHZ) * 1.0 us;
  constant CLOCK_HOLD     : time := CLOCK_PERIOD/10.0;
  
  -- tb clock and reset
  signal tb_clk    : std_logic := '0';
  signal tb_srst   : std_logic := '1';
  
  --tb inputs
  signal tb_a      : std_logic := '0';
  signal tb_b      : std_logic := '0';
  
  --tb outputs
  signal tb_c      : std_logic;

begin

  dut : nand_gate
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
    -- wait for reset to finish
    tb_a <= '0';
    tb_b <= '0';
    wait until tb_srst = '0';
    
    -- test case 1 : 0 nand 0 = 1
    tb_a <= '0';
    tb_b <= '0';
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    assert tb_c = '1'
    report "error 0 nand 0 was 0"
    severity failure;
    
    -- test case 2 : 0 nand 1 = 1
    tb_a <= '0';
    tb_b <= '1';
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    assert tb_c = '1'
    report "error 0 nand 1 was 0"
    severity failure;
    
    -- test case 3 : 1 nand 0 = 1
    tb_a <= '1';
    tb_b <= '0';
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    assert tb_c = '1'
    report "error 1 nand 0 was 0"
    severity failure;
    
    -- test case 4 : 1 and 1 = 0
    tb_a <= '1';
    tb_b <= '1';
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    assert tb_c = '0'
    report "error 1 nand 1 was 1"
    severity failure;
  
    wait until rising_edge(tb_clk);
    report "Testing successful not an error"
    severity failure;
    
    wait;
  
  end process tb_main_proc;

end test_bench;