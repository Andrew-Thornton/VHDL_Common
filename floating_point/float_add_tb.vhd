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
-- This testbench is designed to test all unique cases that could occur during
-- a floating point addition, including NaN and +/- Inf cases
-------------------------------------------------------------------------------
-- Rev  Author        Description
-- 1.0  A. Thornton   Testbench Creation
-- 1.1  A. Thornton   Increased test cases to 4
-- 1.2  A. Thornton   Increased test cases, added zero test cases
--                    Changed common test to a procedure to neaten code
-- 1.3  A. Thornton   Added some NaN tests
-- 1.4  A. Thornton   Added more Inf and -Inf test cases
-- 1.5  A. Thornton   Added test cases for overflow into +/- Inf
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
  signal tb_a      : std_logic_vector(31 downto 0) := (others => '0');
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
    if proc_expect = 0.0 then
      report "Test case " & integer'image(test_case_num);
      report "Expected Value was :" & real'image(proc_expect);
      report "DUT Output         :" & real'image(proc_output);
      assert tb_c = real_to_slv(proc_expect) or (not(tb_c(31)) & tb_c(30 downto 0)) = real_to_slv(proc_expect) -- +/- 0.0
      report "test failed"
      severity failure;
      report "test passed";
    else
      report "Test case " & integer'image(test_case_num);
      report "Expected Value was :" & real'image(proc_expect);
      report "DUT Output         :" & real'image(proc_output);
      assert tb_c = real_to_slv(proc_expect)
      report "test failed"
      severity failure;
      report "test passed";
    end if;
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

  procedure run_nan_nan_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_not_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '0' & x"FF" & 23x"4ccccc";
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
  end procedure run_nan_nan_test_case;

  procedure run_ninf_pinf_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_not_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '1' & x"FF" & 23x"000000";
    tb_b   <= '0' & x"FF" & 23x"000000";
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
  end procedure run_ninf_pinf_test_case;

  procedure run_ninf_nan_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_not_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '1' & x"FF" & 23x"000000";
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
  end procedure run_ninf_nan_test_case;

  procedure run_nan_ninf_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_not_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '0' & x"FF" & 23x"4ccccc";
    tb_b   <= '1' & x"FF" & 23x"000000";
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
  end procedure run_nan_ninf_test_case;

  procedure run_nan_inf_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_not_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '0' & x"FF" & 23x"4ccccc";
    tb_b   <= '0' & x"FF" & 23x"000000";
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
  end procedure run_nan_inf_test_case;

  procedure run_inf_nan_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_not_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '0' & x"FF" & 23x"000000";
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
  end procedure run_inf_nan_test_case;

  procedure run_inf_test_case_input_b(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    constant input_b       : in real;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '0' & x"FF" & 23x"000000";
    tb_b   <= real_to_slv(input_b);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :Inf";
    assert (tb_c(31) = '0') and
           (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) = mand_expect) --ensure infinity
    report "test failed"
    severity failure;
    report "DUT Output         :Inf";
    report "test passed";
  end procedure run_inf_test_case_input_b;

  procedure run_inf_test_case_input_a(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    constant input_a       : in real;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= real_to_slv(input_a);
    tb_b   <= '0' & x"FF" & 23x"000000";
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :Inf";
    assert (tb_c(31) = '0') and
           (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) = mand_expect) --ensure infinity
    report "test failed"
    severity failure;
    report "DUT Output         :Inf";
    report "test passed";
  end procedure run_inf_test_case_input_a;

  procedure run_ninf_test_case_input_b(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    constant input_b       : in real;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '1' & x"FF" & 23x"000000";
    tb_b   <= real_to_slv(input_b);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :-Inf";
    assert (tb_c(31) = '1') and
           (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) = mand_expect) --ensure infinity
    report "test failed"
    severity failure;
    report "DUT Output         :-Inf";
    report "test passed";
  end procedure run_ninf_test_case_input_b;

  procedure run_ninf_test_case_input_a(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    constant input_a       : in real;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= real_to_slv(input_a);
    tb_b   <= '1' & x"FF" & 23x"000000";
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :-Inf";
    assert (tb_c(31) = '1') and
           (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) = mand_expect) --ensure infinity
    report "test failed"
    severity failure;
    report "DUT Output         :-Inf";
    report "test passed";
  end procedure run_ninf_test_case_input_a;

  procedure run_ninf_ninf_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '1' & x"FF" & 23x"000000";
    tb_b   <= '1' & x"FF" & 23x"000000";
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :-Inf";
    assert (tb_c(31) = '1') and
           (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) = mand_expect) --ensure infinity
    report "test failed"
    severity failure;
    report "DUT Output         :-Inf";
    report "test passed";
  end procedure run_ninf_ninf_test_case;

  procedure run_inf_inf_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
      --test case 1 -- adding two positive numbers
    wait for CLOCK_HOLD;
    tb_a   <= '0' & x"FF" & 23x"000000";
    tb_b   <= '0' & x"FF" & 23x"000000";
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :Inf";
    assert (tb_c(31) = '0') and
           (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) = mand_expect) --ensure infinity
    report "test failed"
    severity failure;
    report "DUT Output         :Inf";
    report "test passed";
  end procedure run_inf_inf_test_case;

  procedure run_large_positive_to_inf_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
    -- adding two positive numbers which should overflow into infinity
    wait for CLOCK_HOLD;
    tb_a   <= '0' & x"FE" & 23x"7FFFFF";
    tb_b   <= '0' & x"FE" & 23x"7FFFFF";
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :Inf";
    assert (tb_c(31) = '0') and
           (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) = mand_expect) --ensure positive infinity
    report "test failed"
    severity failure;
    report "DUT Output         :Inf";
    report "test passed";
  end procedure run_large_positive_to_inf_test_case;

  procedure run_large_negative_to_ninf_test_case(
    signal tb_clk          : in std_logic;
    constant test_case_num : in natural;
    signal tb_a            : out std_logic_vector(31 downto 0);
    signal tb_b            : out std_logic_vector(31 downto 0)
  ) is
    constant exp_expect : std_logic_vector(7 downto 0) := x"FF";
    constant mand_expect : std_logic_vector(22 downto 0) := 23x"000000";
  begin
    -- adding two positive numbers which should overflow into infinity
    wait for CLOCK_HOLD;
    tb_a   <= '1' & x"FE" & 23x"7FFFFF";
    tb_b   <= '1' & x"FE" & 23x"7FFFFF";
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait until rising_edge(tb_clk);
    wait for CLOCK_HOLD;
    report "Test case " & integer'image(test_case_num);
    report "Expected Value was :-Inf";
    assert (tb_c(31) = '1') and
           (tb_c(30 downto 23) = (exp_expect)) and
           (tb_c(22 downto  0) = mand_expect) --ensure positive infinity
    report "test failed"
    severity failure;
    report "DUT Output         :Inf";
    report "test passed";
  end procedure run_large_negative_to_ninf_test_case;

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

    -- test case 20 -- NaN + NaN
    run_nan_nan_test_case(tb_clk => tb_clk, test_case_num => 20, tb_a => tb_a , tb_b => tb_b);

    -- test case 21 -- -Inf + Inf
    run_ninf_pinf_test_case(tb_clk => tb_clk, test_case_num => 21, tb_a => tb_a , tb_b => tb_b);

    -- test case 22 -- -Inf + NaN
    run_ninf_nan_test_case(tb_clk => tb_clk, test_case_num => 22, tb_a => tb_a , tb_b => tb_b);

    -- test case 23 -- + NaN - Inf
    run_nan_ninf_test_case(tb_clk => tb_clk, test_case_num => 23, tb_a => tb_a , tb_b => tb_b);

    -- test case 24 -- inf + NaN
    run_inf_nan_test_case(tb_clk => tb_clk, test_case_num => 24, tb_a => tb_a , tb_b => tb_b);

    -- test case 25 -- NaN + inf
    run_nan_inf_test_case(tb_clk => tb_clk, test_case_num => 25, tb_a => tb_a , tb_b => tb_b);

    --test case 26 -- trying to make 0 again
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 26, input_a => 64.0, input_b => -64.0, tb_a => tb_a , tb_b => tb_b);

    --test case 27 -- trying to make 0 again
    run_basic_test_case(tb_clk => tb_clk, test_case_num => 27, input_a => 1000.0, input_b => -1000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 28 -- +inf and numbers
    run_inf_test_case_input_b(tb_clk => tb_clk, test_case_num => 28, input_b => 0.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 29 -- +inf and numbers
    run_inf_test_case_input_b(tb_clk => tb_clk, test_case_num => 29, input_b =>  340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 30 -- +inf and numbers
    run_inf_test_case_input_b(tb_clk => tb_clk, test_case_num => 30, input_b => -340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 31 -- +inf and numbers
    run_inf_test_case_input_b(tb_clk => tb_clk, test_case_num => 31, input_b => -4.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 32 -- +inf and numbers
    run_inf_test_case_input_b(tb_clk => tb_clk, test_case_num => 32, input_b => 4.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 33 -- +inf and numbers
    run_inf_test_case_input_a(tb_clk => tb_clk, test_case_num => 33, input_a => 0.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 34 -- +inf and numbers
    run_inf_test_case_input_a(tb_clk => tb_clk, test_case_num => 34, input_a =>  340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 35 -- +inf and numbers
    run_inf_test_case_input_a(tb_clk => tb_clk, test_case_num => 35, input_a => -340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 36 -- +inf and numbers
    run_inf_test_case_input_a(tb_clk => tb_clk, test_case_num => 36, input_a => -4.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 37 -- +inf and numbers
    run_inf_test_case_input_a(tb_clk => tb_clk, test_case_num => 37, input_a => 4.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 38 -- +inf and numbers
    run_ninf_test_case_input_b(tb_clk => tb_clk, test_case_num => 38, input_b => 0.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 39 -- +inf and numbers
    run_ninf_test_case_input_b(tb_clk => tb_clk, test_case_num => 39, input_b =>  340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 40 -- -inf and numbers
    run_ninf_test_case_input_b(tb_clk => tb_clk, test_case_num => 40, input_b => -340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 41 -- -inf and numbers
    run_ninf_test_case_input_b(tb_clk => tb_clk, test_case_num => 41, input_b => -4.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 42 -- -inf and numbers
    run_ninf_test_case_input_b(tb_clk => tb_clk, test_case_num => 42, input_b => 4.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 43 -- -inf and numbers
    run_ninf_test_case_input_a(tb_clk => tb_clk, test_case_num => 43, input_a => 0.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 44 -- -inf and numbers
    run_ninf_test_case_input_a(tb_clk => tb_clk, test_case_num => 44, input_a =>  340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 45 -- -inf and numbers
    run_ninf_test_case_input_a(tb_clk => tb_clk, test_case_num => 45, input_a => -340282346640000000000000000000000000000.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 46 -- -inf and numbers
    run_ninf_test_case_input_a(tb_clk => tb_clk, test_case_num => 46, input_a => -4.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 47 -- -inf and numbers
    run_ninf_test_case_input_a(tb_clk => tb_clk, test_case_num => 47, input_a => 4.0, tb_a => tb_a , tb_b => tb_b);

    -- test case 48 +inf and +inf = +inf
    run_inf_inf_test_case(tb_clk => tb_clk, test_case_num => 48, tb_a => tb_a , tb_b => tb_b);

    -- test case 49 -inf and -inf = -inf
    run_inf_inf_test_case(tb_clk => tb_clk, test_case_num => 49, tb_a => tb_a , tb_b => tb_b);

    -- test case 50 3.4028234664 × 10^38 + 3.4028234664 × 10^38 = +inf
    run_large_positive_to_inf_test_case(tb_clk => tb_clk, test_case_num => 50, tb_a => tb_a , tb_b => tb_b);

    -- test case 51 -3.4028234664 × 10^38 + -3.4028234664 × 10^38 = -inf
    run_large_negative_to_ninf_test_case(tb_clk => tb_clk, test_case_num => 50, tb_a => tb_a , tb_b => tb_b);

    report "Testing Complete, all passed"
    severity failure;

    wait;

  end process tb_main_proc;

end test_bench;