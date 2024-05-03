-------------------------------------------------------------------------------
-- Copyright (C) 2024 Andrew Thornton - All Rights Reserved
-- Please contact me via andrewthornton9619@gmail.com or via linkedin
-- https://www.linkedin.com/in/andrew-thornton-976a95231/
-- if you would like to use this code.
-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Creation Date : 2024-May-03
-- Standard      : VDHL 2008
-------------------------------------------------------------------------------
-- Rev  Author       Date       Description
-- 0.0  A. Thornton  2024-05-03 WIP
-------------------------------------------------------------------------------
-- Description
-- This module performs an addition of 2 numbers which comply with
-- IEEE-754 Floating Point
-- At revision 1.0 this will not have support for Nan or Inf or subnormal
-- numbers but this will be added soon.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity float_add is
  port(
    clk_i  : in  std_logic;
    srst_i : in  std_logic;
    a_i    : in  std_logic_vector(31 downto 0);
    b_i    : in  std_logic_vector(31 downto 0);
    c_o    : out std_logic_vector(31 downto 0)
  );
end float_add;

architecture rtl of float_add is

  --breaking up the inputs into the respective parts
  signal a_sign   : std_logic;
  signal b_sign   : std_logic;
  signal a_exp    : unsigned( 7 downto 0);
  signal b_exp    : unsigned( 7 downto 0);
  signal a_frac   : unsigned(22 downto 0);
  signal b_frac   : unsigned(22 downto 0);

  -- 1st clock cycle signals
  signal res_sign : std_logic;
  signal a_exp_sr : unsigned( 7 downto 0);
  signal b_exp_sr : unsigned( 7 downto 0);
  signal a_mand   : unsigned(23 downto 0); -- 1 uint and 23 frac
  signal b_mand   : unsigned(23 downto 0); -- 1 uint and 23 frac
  
  -- 2nd and 3rd clock cycle multiplier signals
  signal res_mand1 : unsigned(47 downto 0);
  signal res_mand  : unsigned(47 downto 0);
  
  -- 2nd and 3rd clock cycle exponent signals
  signal a_exp_sr1   : unsigned( 7 downto 0);
  signal b_exp_sr1   : unsigned( 7 downto 0);
  signal res_exp_nbs : unsigned( 8 downto 0);
  
  -- 2nd to 4th clock cycle sign signals
  signal res_sign_sr : std_logic_vector(4 downto 2);
  
  --4th clock cycle bitshifted signals
  signal res_mand_bs : std_logic_vector(23 downto 0);
  signal res_exp_bs  : unsigned( 8 downto 0);

begin

  -- input mapping
  a_sign <= a_i(31);
  b_sign <= b_i(31);
  a_exp  <= unsigned(a_i(30 downto 23));
  b_exp  <= unsigned(b_i(30 downto 23));
  a_frac <= unsigned(a_i(22 downto  0));
  b_frac <= unsigned(b_i(22 downto  0));

  -- This process adds the missing MSB to the mandissa depending on whether the
  -- number is normal or zero or subnormal.
  -- IE the 1 in 1.X is added.
  -- or the 0 in 0.X is added.
  -- When the exponent is zero then the number is subnormal or 0.
  -- This process forms part of the first clock cycle.
  zero_or_non_zero_select : process(clk_i)
    constant EXP_ZEROS : std_logic_vector(7 downto 0) := x"00";
  begin
    if rising_edge(clk_i) then
      if (std_logic_vector(a_exp) = EXP_ZEROS) then
        a_mand <= unsigned('0' & std_logic_vector(a_frac)); -- subnorm or zero
      else
        a_mand <= unsigned('1' & std_logic_vector(a_frac)); -- normal
      end if;
      if (std_logic_vector(b_exp) = EXP_ZEROS) then
        b_mand <= unsigned('0' & std_logic_vector(b_frac)); -- subnorm or zero
      else
        b_mand <= unsigned('1' & std_logic_vector(b_frac)); -- normal
      end if;
      if srst_i = '1' then
        a_mand <= to_unsigned(0,24);
        b_mand <= to_unsigned(0,24);
      end if;
    end if;
  end process zero_or_non_zero_select;
  
  -- This is part of the first clock cycle process and determines if 
  -- the result is going to be positive or negative. 
  result_sign_process : process(clk_i)
  begin
    if rising_edge(clk_i) then`
      -- (+) * (+) = (+) and (-) * (-) = (+)
      if (a_sign = b_sign) then
        res_sign <= '0';
      else
        res_sign <= '1';
      end if;
      if srst_i = '1' then
        res_sign <= '0';
      end if;
    end if;
  end process result_sign_process;

  -- This process just shift registers the exponents for now
  -- this is first clock cycle
  shift_register_proc : process(clk_i)
  begin
    if rising_edge(clk_i) then
      a_exp_sr     <= a_exp;
      b_exp_sr     <= b_exp;
      if srst_i = '1' then
        a_exp_sr <= to_unsigned(0,8);
        b_exp_sr <= to_unsigned(0,8);
      end if;
    end if;
  end process shift_register_proc;
  
  -- This is the multiplier stage, it is the 2nd and 3rd clock cycle
  -- As the DSP has a width of 18*27, 2 or 4 DSPs may be required
  -- Xilinx will automatically pipeline the following.
  multiplier_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      res_mand1 <= a_mand * b_mand; -- 1 int 23 frac
      res_mand  <= res_mand1;
      if srst_i = '1' then
        res_mand1 <= to_unsigned(0,48);
        res_mand  <= to_unsigned(0,48); --2 int 46 frac
      end if;
    end if;
  end process shift_register_proc;
  
  -- This is the exponent calculation stage
  -- This takes two clock cycles 2 and 3 and only takes this long
  -- as the multiplier is the bottle neck
  exponent_res_pre_shift_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      a_exp_sr1   <= a_exp_sr;
      b_exp_sr1   <= b_exp_sr;
      res_exp_nbs <= a_exp_sr1 + b_exp_sr1;
      if srst_i = '1' then
        a_exp_sr1   <= to_unsigned(0,8);
        b_exp_sr1   <= to_unsigned(0,8);
        res_exp_nbs <= to_unsigned(0,9);
      end if;
    end if;
  end process exponent_res_pre_shift_process;

  sign_shift_register : process(clk_i)
  begin
    if rising_edge(clk_i) then
      res_sign_sr(2) <= res_sign;
      res_sign_sr(4 downto 3) <= res_sign_sr(3 downto 2);
      if srst_i = '1' then
        res_sign_sr(4 downto 2) <= (others => '0');
      end if;
    end if;
  end process sign_shift_register;
  
  -- The 4th clock cycle is re bitshifting in case of 
  -- mandissa overflow or underflow
  bitshift_process : process(clk_i)
    constant MAND_2_0 : std_logic_vector(23 downto 0) := "100000000000000000000000"; --2 int 46 frac
    constant MAND_1_0 : std_logic_vector(23 downto 0) := "010000000000000000000000"; --2 int 46 frac
  begin
    if rising_edge(clk_i) then
      if res_mand(47 downto 24) >= MAND_2_0 then
        res_mand_bs <= std_logic_vector(res_mand(47 downto 24)));
        res_exp_bs  <= res_exp_nbs + unsigned(1,9);
      elsif res_mand(47 downto 24) < MAND_1_0 then
        res_mand_bs <= std_logic_vector(res_mand(45 downto 22)));
        res_exp_bs  <= res_exp_nbs - unsigned(1,9);
      else
        res_mand_bs <= std_logic_vector(res_mand(46 downto 23)));
        res_exp_bs  <= res_exp_nbs;
      end if;
    end if;
  end process bitshift_process;

  -- output mapping
  c_o(31)           <= res_sign_sr(4) ;
  c_o(30 downto 23) <= std_logic_vector(res_exp_bs(8 downto 0));
  c_o(22 downto  0) <= std_logic_vector(res_mand_bs(23 downto 1));

end rtl;