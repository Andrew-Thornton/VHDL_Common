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
-- 1.0  A. Thornton   Module Creation
-------------------------------------------------------------------------------
-- Description
-- This module performs an addition of 2 numbers which comply with 
-- IEEE-754 Floating Point
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
  signal a_sign  : std_logic;
  signal b_sign  : std_logic;
  signal a_exp   : unsigned( 7 downto 0);
  signal b_exp   : unsigned( 7 downto 0);
  signal a_mand  : unsigned(23 downto 0); -- 1 uint and 23 frac
  signal b_mand  : unsigned(23 downto 0); -- 1 uint and 23 frac
  
  -- 1st clock cycle signals
  signal is_mod_a_bigger : std_logic_vector(1 downto 0);
  signal exp_dif         : unsigned(7 downto 0);
  
  -- 2nd clock cycle signals
  signal exp_both              : unsigned( 7 downto 0);
  signal a_mand_bitshifted     : unsigned(24 downto 0); -- 1 uint 24 frac
  signal b_mand_bitshifted     : unsigned(24 downto 0); -- 1 uint 24 frac
  signal a_mand_bitshifted_se  : unsigned(25 downto 0); -- 2 uint 24 frac
  signal b_mand_bitshifted_se  : unsigned(25 downto 0); -- 2 uint 24 frac
  
  --3rd clock cycle signals
  signal result_sign           : std_logic;
  signal result_exp            : unsigned( 7 downto 0);
  signal result_mand_unshifted : unsigned(25 downto 0); -- 2 uint 24 frac

  --4th clock cycle signals
  signal result_sign_final     : std_logic;
  signal result_exp_shifted    : unsigned( 7 downto 0);
  signal result_mand_shifted   : unsigned(25 downto 0);

begin

  -- input mapping
  a_sign <= a_i(31);
  b_sign <= b_i(31);
  a_exp  <= unsigned(a_i(30 downto 23));
  b_exp  <= unsigned(b_i(30 downto 23));
  a_mand <= unsigned('1' & a_i(22 downto  0));
  b_mand <= unsigned('1' & b_i(22 downto  0));
  
  -- first part of the process is to decide which is bigger, 
  -- and then adjust the other 
  max_exp_decide : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if a_exp = b_exp then
        if a_mand > b_mand then
          is_mod_a_bigger(0) <= '1';
        else
          is_mod_a_bigger(0) <= '0';
        end if;
        exp_dif <= to_unsigned(0,8);
      elsif a_exp > b_exp then
        is_mod_a_bigger(0) <= '1';
        exp_dif        <= a_exp - b_exp;
      else -- a_exp < b_exp
        is_mod_a_bigger(0) <= '0';
        exp_dif        <= b_exp - a_exp;
      end if;
    end if;
  end process max_exp_decide;
  
  -- next part is to bitshift smaller number to be in the same 
  -- ball park as the bigger number
  bitshift_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      is_mod_a_bigger(1) <= is_mod_a_bigger(0);
      if is_mod_a_bigger(0) = '1' then
        a_mand_bitshifted <= unsigned(std_logic_vector(a_mand) & '0');
        b_mand_bitshifted <= shift_right(unsigned(std_logic_vector(b_mand) & '0'),to_integer(exp_dif));
        exp_both          <= a_exp;
      else
        a_mand_bitshifted <= shift_right(unsigned(std_logic_vector(a_mand) & '0'),to_integer(exp_dif));
        b_mand_bitshifted <= unsigned(std_logic_vector(b_mand) & '0');
        exp_both          <= b_exp;
      end if;
    end if;
  end process bitshift_process;
  

  
  -- sign extend so that it allows for bit growth in addition
  a_mand_bitshifted_se <= unsigned('0' & std_logic_vector(a_mand_bitshifted));
  b_mand_bitshifted_se <= unsigned('0' & std_logic_vector(b_mand_bitshifted));
  -- next step is to perform the maths now that the numbers both have the 
  -- higher of the exponents
  math_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      result_exp <= exp_both;
      if (a_sign = '0') and (b_sign = '0') then 
        -- both numbers are positive and we can just add
        result_mand_unshifted <= a_mand_bitshifted_se + b_mand_bitshifted_se;
        result_sign           <= '0'; -- pos
      elsif (a_sign = '1') and (b_sign = '1') then 
        -- both numbers are negative and we can just add the fractions
        result_mand_unshifted <= a_mand_bitshifted_se + b_mand_bitshifted_se;
        result_sign           <= '1'; -- neg
      elsif (is_mod_a_bigger(1) = '1') and (a_sign = '1') and (b_sign = '0') then 
        -- a has a bigger modulus, and is negative, 
        -- b is positive
        -- the result here will be a smaller negative number
        result_mand_unshifted <= a_mand_bitshifted_se - b_mand_bitshifted_se;
        result_sign           <= '1'; -- neg
      elsif (is_mod_a_bigger(1) = '1') and (a_sign = '0') and (b_sign = '1') then
        -- a has a bigger modulus, and is positive,
        -- b is negative
        -- the result here will be a smaller positive number
        result_mand_unshifted <= a_mand_bitshifted_se - b_mand_bitshifted_se;
        result_sign           <= '0'; -- pos
      elsif (is_mod_a_bigger(0) = '0') and (a_sign = '1') and (b_sign = '0') then
        -- a is negative
        -- b has a bigger modulus, and is positive, 
        -- the result here will be a smaller positive number
        result_mand_unshifted <= b_mand_bitshifted_se - a_mand_bitshifted_se;
        result_sign           <= '0'; -- pos
      else --if (is_mod_a_bigger(0) = '0') and (a_sign = '0') and (b_sign = '1') then
        -- a is positive
        -- b has a bigger modulus, and is negative, 
        -- the result here will be a smaller negative number
        result_mand_unshifted <= b_mand_bitshifted_se - a_mand_bitshifted_se;
        result_sign           <= '1'; -- neg 
--      else
--        result_mand_unshifted <= to_unsigned(0,24);
--        result_sign <= '0';
      end if;
    end if;
  end process math_process;
  
  -- this process aims at ensuring the result is in scientific notation
  -- ie 1.27*2^x
  -- unless the number is extremely small and there is no further exponent range
  re_normalise_proc : process(clk_i)
  begin
    if rising_edge(clk_i) then
      result_sign_final <= result_sign;
      if result_mand_unshifted(25) = '1' then
        --bitgrowth has occurred and we need to shift the exponent or divide by 2
        result_exp_shifted  <= result_exp + 1;
        result_mand_shifted <= shift_right(result_mand_unshifted,1);
      elsif result_mand_unshifted(24) = '1' then --result is 1.something or 1<=X<2
        result_exp_shifted  <= result_exp;
        result_mand_shifted <= result_mand_unshifted; 
      elsif result_mand_unshifted = to_unsigned(0,26) then
        result_exp_shifted  <= to_unsigned(0,8);
        result_mand_shifted <= to_unsigned(0,26);
      else
        for i in 1 to 24 loop
          if result_mand_unshifted(24-i) = '1' then
            result_exp_shifted  <= result_exp - i;
            result_mand_shifted <= shift_left(result_mand_unshifted,i);
          end if;
        end loop;
      end if;
    end if;
  end process re_normalise_proc;
  
  --output mapping
  c_o(31)           <= result_sign_final;
  c_o(30 downto 23) <= std_logic_vector(result_exp_shifted);
  c_o(22 downto  0) <= std_logic_vector(result_mand_shifted(23 downto 1));
 
end rtl;