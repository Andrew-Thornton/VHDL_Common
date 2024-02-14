-------------------------------------------------------------------------------
-- Copyright (C) 2023 Andrew Thornton - All Rights Reserved
-- Please contact me via andrewthornton9619@gmail.com or via linkedin
-- https://www.linkedin.com/in/andrew-thornton-976a95231/
-- if you would like to use this code.
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Creation Date : 2024-Jan-14
-- Standard      : VDHL 2008
-------------------------------------------------------------------------------
-- Rev  Author        Date        Description
-- 1.0  A. Thornton   2024-Jan-14 Testbench Creation
-- 1.1  A. Thornton   2024-Jan-14 Real numbers were going to high in tb,
--                                so added a limit to the expected answer to
--                                properly get to infinity
-- 1.2  A. Thornton   2024-Jan-15 Neatening
-- 1.3  A. Thornton   2024-Feb-02 Added another clock cycle to meet changed dut
-- 1.4  A. Thornton   2024-Feb-13 Added reset to a signal
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.common_float_tools_pkg.all;

entity float_add_speed_tb is
end float_add_speed_tb;

architecture test_bench of float_add_speed_tb is

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

  -- checking signals
  signal tb_a_real         : real;
  signal tb_b_real         : real;
  signal tb_a_plus_b       : real;
  signal tb_a_plus_b_sr    : real;
  signal tb_expect         : std_logic_vector(31 downto 0);
  signal tb_expect_ff      : std_logic_vector(31 downto 0);
  signal tb_chk_rdy_sr     : std_logic_vector(4 downto 0);
  signal tb_nan_detect     : std_logic_vector(2 downto 0);
  signal tb_inf_detect     : std_logic_vector(2 downto 0);
  signal tb_inf_sign       : std_logic_vector(2 downto 0);

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

  -- This code has been modified slightly from VHDLwhiz random number generator
  -- blog
  -- https://vhdlwhiz.com/random-numbers/
  random_input_generation_proc : process(tb_clk)
    variable seed1 : integer := 4096;
    variable seed2 : integer := 7;

    impure function rand_slv32 return slv32 is
      variable r       : real;
      variable slv_out : slv32;
    begin
      for i in 0 to 31 loop
        uniform(seed1, seed2, r);
        slv_out(i) := '1' when r > 0.5 else '0';
      end loop;
      return slv_out;
    end function;

   begin
    if rising_edge(tb_clk) then
      if tb_srst = '1' then
        tb_a <= (others => '0');
        tb_b <= (others => '0');
      else
        tb_a <= rand_slv32;
        tb_b <= rand_slv32;
      end if;
    end if;
  end process;

  output_calculator_proc : process(tb_clk)
    constant INF_OR_NAN_EXP : std_logic_vector( 7 downto 0) := x"FF";
    constant INF_MANT       : std_logic_vector(22 downto 0) := 23x"000000";
    constant NAN_MANT       : std_logic_vector(22 downto 0) := 23x"000001";
    constant LARGEST_NUM    : std_logic_vector(31 downto 0) := x"7f7fffff";
    constant SMALLEST_NUM   : std_logic_vector(31 downto 0) := x"ff7fffff";
  begin
    if rising_edge(tb_clk) then
      if tb_srst = '1' then
        tb_a_real       <= 0.0;
        tb_b_real       <= 0.0;
        tb_a_plus_b     <= 0.0;
        tb_a_plus_b_sr  <= 0.0;
        tb_expect       <= (others => '0');
        tb_expect_ff    <= (others => '0');
        tb_chk_rdy_sr   <= (others => '0');
        tb_nan_detect   <= (others => '0');
        tb_inf_detect   <= (others => '0');
        tb_inf_sign     <= (others => '0');
      else
        tb_chk_rdy_sr(0) <= '1';
        tb_chk_rdy_sr(4 downto 1) <= tb_chk_rdy_sr(3 downto 0);
        -- clock cycle 1 convert the inputs to reals
        tb_a_real       <= slv_to_real(tb_a);
        tb_b_real       <= slv_to_real(tb_b);

        --clock cycle 1 inf and nan detection
        tb_nan_detect(0) <= '0';
        tb_inf_detect(0) <= '0';
        tb_inf_sign(0)   <= '0';
        if (std_logic_vector(tb_a(30 downto 23)) = INF_OR_NAN_EXP) then
          if (std_logic_vector(tb_a(22 downto 0)) = INF_MANT) then
            --infinity detected
            tb_inf_detect(0) <= '1';
            tb_inf_sign(0)   <= tb_a(31);
          else
            tb_nan_detect(0) <= '1';
          end if;
        end if;
        if (std_logic_vector(tb_b(30 downto 23)) = INF_OR_NAN_EXP) then
          if (std_logic_vector(tb_b(22 downto 0)) = INF_MANT) then
            tb_inf_detect(0) <= '1';
            tb_inf_sign(0)   <= tb_b(31);
          else
            tb_nan_detect(0) <= '1';
          end if;
        end if;
        --special case where both numbers are infinity but different sign
        if (std_logic_vector(tb_a(30 downto 23)) = INF_OR_NAN_EXP) then
          if (std_logic_vector(tb_b(30 downto 23)) = INF_OR_NAN_EXP) then
            if tb_a(31) /= tb_b(31) then
              tb_nan_detect(0) <= '1';
              tb_inf_detect(0) <= '0';
            end if;
          end if;
        end if;
        tb_nan_detect(2 downto 1) <= tb_nan_detect(1 downto 0);
        tb_inf_detect(2 downto 1) <= tb_inf_detect(1 downto 0);
        tb_inf_sign(2 downto 1)   <= tb_inf_sign(1 downto 0);

        -- clock cycle 2 add the reals together
        tb_a_plus_b     <= tb_a_real + tb_b_real;

        -- clock cycle 3 delay the result waiting for return
        tb_a_plus_b_sr  <= tb_a_plus_b;
        if tb_a_plus_b > slv_to_real(LARGEST_NUM) then
          tb_inf_detect(2) <= '1';
          tb_inf_sign(2)   <= '0';
        end if;
        if tb_a_plus_b < slv_to_real(SMALLEST_NUM) then
          tb_inf_detect(2) <= '1';
          tb_inf_sign(2)   <= '1';
        end if;

        -- clock cycle 4 convert expected output
        if tb_nan_detect(2) = '1' then
          tb_expect       <= '0' & INF_OR_NAN_EXP & NAN_MANT;
        elsif tb_inf_detect(2) = '1' then
          tb_expect       <= tb_inf_sign(2) & INF_OR_NAN_EXP & INF_MANT;
        else
          tb_expect       <= real_to_slv(tb_a_plus_b_sr);
        end if;

        -- clock cycle 5 delay the expected output again to match dut
        tb_expect_ff <= tb_expect;

        -- clock cycle 6 check predicted to actual
        -- also allow it to be 1 out due to rounding errors
        if tb_chk_rdy_sr(4) = '1' then
          assert (tb_expect_ff = tb_c) or
                 (std_logic_vector(signed(tb_expect_ff)-1) = tb_c) or
                 (std_logic_vector(signed(tb_expect_ff)+1) = tb_c)
          report "ERROR output was not what was expected"
          severity failure;
        end if;
      end if;
    end if;
  end process output_calculator_proc;


end test_bench;