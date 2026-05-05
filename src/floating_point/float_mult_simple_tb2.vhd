-------------------------------------------------------------------------------
-- Copyright (C) 2025 Andrew Thornton - All Rights Reserved
-- Please contact me via andrewthornton9619@gmail.com or via linkedin
-- https://www.linkedin.com/in/andrew-thornton-976a95231/
-- if you would like to use this code.
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Creation Date : 2025-Dec-09
-- Standard      : VDHL 2008
-------------------------------------------------------------------------------
-- This testbench is designed to test all unique cases that could occur during
-- a floating point multiplication, including NaN and +/- Inf cases
-------------------------------------------------------------------------------
-- Rev  Author        Description
-- 0.0  A. Thornton   Work in Progress
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.float_pkg.all; 

library work;
use work.common_float_tools_pkg.all;

entity float_mult_simple_tb2 is
end float_mult_simple_tb2;

architecture test_bench of float_mult_simple_tb2 is

  component float_mult is
    port(
      clk_i  : in  std_logic;
      srst_i : in  std_logic;
      a_i    : in  std_logic_vector(31 downto 0);
      b_i    : in  std_logic_vector(31 downto 0);
      c_o    : out std_logic_vector(31 downto 0)
    );
  end component;

  constant CLOCK_FREQ_MHZ : real := 100.0;
  constant CLOCK_PERIOD   : time := (1.0/CLOCK_FREQ_MHZ) * 1.0 us;
  constant CLOCK_HOLD     : time := CLOCK_PERIOD/10.0;

  constant DUT_LATENCY_CC : natural := 6; 

  constant TB_NAN_SLV              : std_logic_vector(31 downto 0) := '0' & x"FF" & 23x"4ccccc";
  constant TB_PINF_SLV             : std_logic_vector(31 downto 0) := '0' & x"FF" & 23x"000000";
  constant TB_NINF_SLV             : std_logic_vector(31 downto 0) := '1' & x"FF" & 23x"000000";
  constant TB_ZERO_SLV             : std_logic_vector(31 downto 0) := '0' & x"00" & 23x"000000";
  constant TB_SMALLEST_SUB_POS_SLV : std_logic_vector(31 downto 0) := '0' & x"00" & 23x"000001";
  constant TB_SMALLEST_SUB_NEG_SLV : std_logic_vector(31 downto 0) := '1' & x"00" & 23x"000001";
  constant TB_LARGEST_POS_SLV      : std_logic_vector(31 downto 0) := '0' & x"FF" & 23x"7FFFFF";
  constant TB_LARGEST_NEG_SLV      : std_logic_vector(31 downto 0) := '1' & x"FF" & 23x"7FFFFF";
  constant TB_LARGEST_SUB_POS_SLV  : std_logic_vector(31 downto 0) := '0' & x"00" & 23x"7FFFFF";
  constant TB_LARGEST_SUB_NEG_SLV  : std_logic_vector(31 downto 0) := '1' & x"00" & 23x"7FFFFF";

  constant TB_NAN                  : float32 := to_float(TB_NAN_SLV,8,23);
  constant TB_PINF                 : float32 := to_float(TB_PINF_SLV,8,23);
  constant TB_NINF                 : float32 := to_float(TB_NINF_SLV,8,23);
  constant TB_ZERO                 : float32 := to_float(TB_ZERO_SLV,8,23);
  constant TB_SMALLEST_SUB_POS     : float32 := to_float(TB_SMALLEST_SUB_POS_SLV,8,23);
  constant TB_SMALLEST_SUB_NEG     : float32 := to_float(TB_SMALLEST_SUB_NEG_SLV,8,23);
  constant TB_LARGEST_POS          : float32 := to_float(TB_LARGEST_POS_SLV,8,23);
  constant TB_LARGEST_NEG          : float32 := to_float(TB_LARGEST_NEG_SLV,8,23);
  constant TB_LARGEST_SUB_POS      : float32 := to_float(TB_LARGEST_SUB_POS_SLV,8,23);
  constant TB_LARGEST_SUB_NEG      : float32 := to_float(TB_LARGEST_SUB_NEG_SLV,8,23);

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

--   type test_case_t is record
--     a : float32;
--     b : float32;
--   end record;

--   type test_cases_t is array (natural range <>) of test_case_t;
  
-- constant TB_TEST_CASES : test_cases_t(0 to 143) :=
--   (others => (a => to_float(0.42), b => to_float(0.42)));

  type test_case_t is array(natural range<>) of float32;


  constant TB_TEST_NUMBERS : test_case_t(0 to 19) := (
    to_float(2.0),
    to_float(1.0),
    to_float(-2.0),
    to_float(-1.0),
    to_float(0.0),
    to_float(-0.0),
    to_float(0.5),
    to_float(-0.5),
    to_float(0.125),
    to_float(-0.125),
    to_float(TB_NAN_SLV),
    to_float(TB_PINF_SLV),
    to_float(TB_NINF_SLV),
    to_float(TB_ZERO_SLV),
    to_float(TB_SMALLEST_SUB_POS_SLV),
    to_float(TB_SMALLEST_SUB_NEG_SLV),
    to_float(TB_LARGEST_POS_SLV),
    to_float(TB_LARGEST_NEG_SLV),
    to_float(TB_LARGEST_SUB_POS_SLV),
    to_float(TB_LARGEST_SUB_NEG_SLV)
--    others => to_float(0.42)
  );

begin

  dut : float_mult
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

    procedure run_test_case(
      constant input_a       : in  float32;
      constant input_b       : in  float32;
      signal clk             : in  std_logic;
      signal a               : out std_logic_vector(31 downto 0);
      signal b               : out std_logic_vector(31 downto 0);
      signal c               : in  std_logic_vector(31 downto 0)
    ) is
      variable proc_expect : float32;
      variable proc_expect_slv : std_logic_vector(31 downto 0);
      variable proc_output_slv : std_logic_vector(31 downto 0);
    begin
      wait for CLOCK_HOLD;
      a   <= to_slv(input_a);
      b   <= to_slv(input_b);

      proc_expect := input_a * input_a;
      proc_expect_slv := to_slv(proc_expect);
      for i in 0 to DUT_LATENCY_CC loop
        wait until rising_edge(clk);
      end loop;

      wait for CLOCK_HOLD;
      if proc_expect = 0.0 then
        report "Input A is  " & to_string(input_a);
        report "Input B is  " & to_string(input_b);
        report "Expected Value was :" & to_string(proc_expect);
        report "DUT Output         :" & to_string((to_float(c)));
        assert c = proc_expect_slv or (not(c(31)) & c(30 downto 0)) = proc_expect_slv -- +/- 0.0
        report "test failed"
        severity failure;
        report "test passed";
      else
        report "Input A is  " & to_string(input_a);
        report "Input B is  " & to_string(input_b);
        report "Expected Value was :" & to_string(proc_expect);
        report "DUT Output         :" & to_string((to_float(c)));
        assert tb_c = proc_expect_slv
        report "test failed"
        severity failure;
        report "test passed";
      end if;
    end procedure run_test_case;

  begin

    wait until tb_srst = '0';

    for i in TB_TEST_NUMBERS'range loop
      for j in TB_TEST_NUMBERS'range loop
        run_test_case(TB_TEST_NUMBERS(i),TB_TEST_NUMBERS(j), tb_clk, tb_a, tb_b, tb_c);
      end loop;
    end loop;
    wait;

  end process tb_main_proc;

end test_bench;