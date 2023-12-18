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
-- 1.2  A. Thornton   Increased test cases, added zero test cases
--                    Changed common test to a procedure to neaten code
-- 1.3  A. Thornton   Added some NaN tests
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

  --expected output
  signal tb_expect : real;

  procedure run_basic_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    constant input_a       : in real;
    constant input_b       : in real;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    variable proc_expect : real;
    variable proc_output : real;
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= real_to_slv(input_a);
    tb_b   <= real_to_slv(input_b);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    proc_expect := input_a + input_b;
    proc_output := slv_to_real(tb_c);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :" & real'image(proc_expect);
    report "DUT Output         :" & real'image(proc_output);
    assert tb_c = real_to_slv(proc_expect)
    report "test failed"
    severity failure;
    report "test passed";
  end procedure run_basic_test_case;

  procedure run_nan_test_case_input_b(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    constant input_b       : in real;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_not_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '0' & x"FF" & 23x"4ccccc";
    tb_b   <= real_to_slv(input_b);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :NaN";
    assert (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) /= mand_not_expect) --ensure not infinity and NaN
    report "test failed"
    severity failure;
    report "DUT Output         :NaN";
    report "test passed";
  end procedure run_nan_test_case_input_b;

  procedure run_nan_test_case_input_a(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    constant input_a       : in real;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_not_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= real_to_slv(input_a);
    tb_b   <= '0' & x"FF" & 23x"4ccccc";
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :NaN";
    assert (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) /= mand_not_expect) --ensure not infinity and NaN
    report "test failed"
    severity failure;
    report "DUT Output         :NaN";
    report "test passed";
  end procedure run_nan_test_case_input_a;

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
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 1, input_a => 0.15625, input_b => 0.3125, tb_a => tb_a , tb_b => tb_b);

    --test case 2 -- adding two negative numbers
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 2, input_a => -0.15625, input_b => -0.3125, tb_a => tb_a , tb_b => tb_b);

    --test case 3 -- adding one positive and one negative number
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 3, input_a => 0.15625, input_b => -0.3125, tb_a => tb_a , tb_b => tb_b);

    --test case 4 -- adding one positive and one negative number
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 4, input_a => -0.15625, input_b => 0.3125, tb_a => tb_a , tb_b => tb_b);

    --test case 5 -- adding two positive numbers
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 5, input_a => 0.3125, input_b => 0.15625, tb_a => tb_a , tb_b => tb_b);

    --test case 6 -- adding two negative numbers
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 6, input_a => -0.3125, input_b => -0.15625, tb_a => tb_a , tb_b => tb_b);

    --test case 7 -- adding one positive and one negative number
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 7, input_a => -0.3125, input_b => 0.15625, tb_a => tb_a , tb_b => tb_b);

    --test case 8 -- adding one positive and one negative number
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 8, input_a => 0.3125, input_b => -0.15625, tb_a => tb_a , tb_b => tb_b);

    -- test case 9 -- two zeros
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 9, input_a => 0.0, input_b => 0.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 10 -- zero and positive
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 10, input_a => 0.0, input_b => 0.125, tb_a => tb_a , tb_b => tb_b);

    -- test case 11 -- zero and negative
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 11, input_a => 0.0, input_b => 15.875, tb_a => tb_a , tb_b => tb_b);

    -- test case 12 -- positive and zero
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 12, input_a => 0.00048, input_b => 0.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 13 -- negative and zero
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 13, input_a => -100000.0, input_b => 0.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 14 -- NAN test
    run_nan_test_case_input_b(tb_clk => tb_clk, test_case_num => 14, input_b => 0.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 15 -- NAN test
    run_nan_test_case_input_b(tb_clk => tb_clk, test_case_num => 15, input_b =>  340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 16 -- NAN test
    run_nan_test_case_input_b(tb_clk => tb_clk, test_case_num => 16, input_b => -340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 17 -- NAN test
    run_nan_test_case_input_a(tb_clk => tb_clk, test_case_num => 17, input_a => 0.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 18 -- NAN test
    run_nan_test_case_input_a(tb_clk => tb_clk, test_case_num => 18, input_a =>  340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 19 -- NAN test
    run_nan_test_case_input_a(tb_clk => tb_clk, test_case_num => 19, input_a => -340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    report "Testing Complete, all passed"
    severity failure;

    wait;

  end process tb_main_proc;

end test_bench;