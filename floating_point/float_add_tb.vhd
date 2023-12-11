-------------------------------------------------------------------------------
-- Copyright (C) 2023 Andrew Thornton - All Rights Reserved
-- Please contact me via andrewthornton9619@gmail.com or via linkedin
-- https://www.linkedin.com/in/andrew-thornton-976a95231/
-- if you would like to use this code.
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Creation Date : 2023-Dec-09
-- Standard      : VDHL 2008
-------------------------------------------------------------------------------
-- Rev  Author        Description
-- 1.0  A. Thornton   Testbench Creation
-- 1.1  A. Thornton   Increased test cases to 4
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
  signal a_real    : real := 0.0;
  signal tb_a      : std_logic_vector(31 downto 0) := (others => '0');
  signal b_real    : real := 0.0;
  signal tb_b      : std_logic_vector(31 downto 0) := (others => '0');

  --tb outputs
  signal tb_c      : std_logic_vector(31 downto 0);
  signal c_real    : real;

  --expected output
  signal tb_expect : real;

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

    wait until tb_srst = '0';

    --test case 1 -- adding two positive numbers
    a_real <= 0.15625;
    b_real <= 0.3125;
    wait for CLOCK_HOLD;
    tb_a   <= real_to_slv(a_real);
    tb_b   <= real_to_slv(b_real);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    tb_expect <= a_real + b_real;
    c_real    <= slv_to_real(tb_c);
    wait for CLOCK_HOLD;
    report "Test case 1";
    report "Expected Value was :" & real'image(tb_expect);
    report "DUT Output         :" & real'image(c_real);
    assert tb_c = real_to_slv(tb_expect)
    report "test failed"
    severity failure;
    report "test passed";

    --test case 2 -- adding two negative numbers
    wait for CLOCK_HOLD;
    a_real <= -0.15625;
    b_real <= -0.3125;
    wait for CLOCK_HOLD;
    tb_a   <= real_to_slv(a_real);
    tb_b   <= real_to_slv(b_real);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    tb_expect <= a_real + b_real;
    c_real    <= slv_to_real(tb_c);
    wait for CLOCK_HOLD;
    report "Test case 2";
    report "Expected Value was :" & real'image(tb_expect);
    report "DUT Output         :" & real'image(c_real);
    assert tb_c = real_to_slv(tb_expect)
    report "test failed"
    severity failure;
    report "test passed";

    --test case 3 -- adding one positive and one negative numbers
    wait for CLOCK_HOLD;
    a_real <= 0.15625;
    b_real <= -0.3125;
    wait for CLOCK_HOLD;
    tb_a   <= real_to_slv(a_real);
    tb_b   <= real_to_slv(b_real);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    tb_expect <= a_real + b_real;
    c_real    <= slv_to_real(tb_c);
    wait for CLOCK_HOLD;
    report "Test case 3";
    report "Expected Value was :" & real'image(tb_expect);
    report "DUT Output         :" & real'image(c_real);
    assert tb_c = real_to_slv(tb_expect)
    report "test failed"
    severity failure;
    report "test passed";

    --test case 4 -- adding two negative numbers
    wait for CLOCK_HOLD;
    a_real <= -0.15625;
    b_real <= 0.3125;
    wait for CLOCK_HOLD;
    tb_a   <= real_to_slv(a_real);
    tb_b   <= real_to_slv(b_real);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    tb_expect <= a_real + b_real;
    c_real    <= slv_to_real(tb_c);
    wait for CLOCK_HOLD;
    report "Test case 4";
    report "Expected Value was :" & real'image(tb_expect);
    report "DUT Output         :" & real'image(c_real);
    assert tb_c = real_to_slv(tb_expect)
    report "test failed"
    severity failure;
    report "test passed";

    wait;

  end process tb_main_proc;

end test_bench;