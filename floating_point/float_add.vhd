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
-- Rev  Author       Date       Description
-- 1.0  A. Thornton  2023-12-09 Module Creation
-- 1.1  A. Thornton  2023-12-10 Changed Licensing, fixed error due to if
--                              statement prioritisation order in VHDL in the
--                              renormalisation process
-- 1.2  A. Thornton  2023-12-10 Amended issue where integer is added for zero
--                              numbers. Furthermore added check that if
--                              the value is 0, dont look to bitshift to bring
--                              into the range of 1.0<=X<2,
--                              as this is impossible
-- 1.3  A. Thornton  2023-12-18 Added in NaN and Inf support.
--                              Amended error where wrong signal was used in
--                              deciding the bigger modulus in clock cycle 1
--                              Added subnormal number support
-- 1.4  A. Thornton  2023-12-18 Amended error when result from subtraction is
--                              zero
-- 1.5  A. Thornton  2024-01-08 Fixed handling of overflow into +/- infinity
-- 1.6  A. Thornton  2024-01-08 Fixed handling of subnormal numbers and
--                              subnormal number overflow into the normal
--                              number range
-- 1.7  A. Thornton  2024-01-14 Fixed errors which resulted in the code not
--                              being able to have a continous input stream
--                              where there was an error in not shift
--                              registering the signs and exponents.
--                              Amended a bug where the wrong shift register
--                              value was being checked in an if statement
--                              resulting in potentially wrong signs.
-- 1.8  A. Thornton  2024-01-14 Made NAN always positive
-- 1.9  A. Thornton  2024-01-14 Fixed phenomena where the exp difference is a
--                              factor of 1 out when adding one normal and one
--                              subnormal number resulting in the bitshifting
--                              being incorrect
-- 1.10 A. Thornton  2024-01-14 Amended condition on bitshifting when moving
--                              from normal numbers to a subnormal number
-- 1.11 A. Thornton  2024-01-14 Code neatening and comment cleanup
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
  signal a_sign   : std_logic;
  signal b_sign   : std_logic;
  signal a_exp    : unsigned( 7 downto 0);
  signal b_exp    : unsigned( 7 downto 0);
  signal a_frac   : unsigned(22 downto 0);
  signal b_frac   : unsigned(22 downto 0);

  -- 1st clock cycle signals
  signal exp_dif   : unsigned(7 downto 0);
  signal a_exp_sr  : unsigned( 7 downto 0);
  signal b_exp_sr  : unsigned( 7 downto 0);
  signal a_mand    : unsigned(23 downto 0); -- 1 uint and 23 frac
  signal b_mand    : unsigned(23 downto 0); -- 1 uint and 23 frac

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

  --multi cycle signals
  signal mod_a_bgr       : std_logic_vector(1 downto 0);
  signal nan_detected    : std_logic_vector(2 downto 0);
  signal inf_detected    : std_logic_vector(2 downto 0);
  signal a_sign_sr       : std_logic_vector(1 downto 0);
  signal b_sign_sr       : std_logic_vector(1 downto 0);

begin

  -- input mapping
  a_sign <= a_i(31);
  b_sign <= b_i(31);
  a_exp  <= unsigned(a_i(30 downto 23));
  b_exp  <= unsigned(b_i(30 downto 23));
  a_frac <= unsigned(a_i(22 downto  0));
  b_frac <= unsigned(b_i(22 downto  0));

  -- first part of the process is to decide which modulus is bigger by a
  -- comparrison. During this process the difference between the exponentials
  -- is also calculated where this is the following
  -- normal numbers               : exp(biggest mod) - exp(smallest mod)
  -- smallest number is subnormal : exp(biggest mod) - exp(smallest mod) - 1
  -- This process forms part of the first clock cycle
  max_exp_decide : process(clk_i)
    constant EXP_ZEROS : std_logic_vector(7 downto 0) := x"00";
  begin
    if rising_edge(clk_i) then
      if a_exp = b_exp then
        if a_frac > b_frac then
          mod_a_bgr(0) <= '1';
        else
          mod_a_bgr(0) <= '0';
        end if;
        exp_dif <= to_unsigned(0,8);
      elsif a_exp > b_exp then
        mod_a_bgr(0) <= '1';
        exp_dif      <= a_exp - b_exp; -- normal
        if std_logic_vector(b_exp) = EXP_ZEROS then
          exp_dif    <= a_exp - b_exp - 1; -- subnormal
        end if;
      else -- a_exp < b_exp
        mod_a_bgr(0) <= '0';
        exp_dif      <= b_exp - a_exp; -- normal
        if std_logic_vector(a_exp) = EXP_ZEROS then
          exp_dif    <= b_exp - a_exp - 1; -- subnormal
        end if;
      end if;
    end if;
  end process max_exp_decide;

  -- This process adds the missing integer part to a number if the number
  -- is normal and not zero or subnormal.
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
    end if;
  end process zero_or_non_zero_select;

  -- This process performs shift registering to remember the input values
  -- for future usage.
  -- This process forms part of the first clock cycle.
  shift_register_proc : process(clk_i)
  begin
    if rising_edge(clk_i) then
      a_exp_sr     <= a_exp;
      b_exp_sr     <= b_exp;
      a_sign_sr(0) <= a_sign;
      b_sign_sr(0) <= b_sign;
    end if;
  end process shift_register_proc;

  -- This process checks for Nan and Inf and places the detection into a
  -- shift register for later use.
  -- This process forms part of the first clock cycle.
  nan_detection : process(clk_i)
    constant INF_OR_NAN_EXP : std_logic_vector( 7 downto 0) := x"FF";
    constant INF_MAND       : std_logic_vector(22 downto 0) := 23x"000000";
  begin
    if rising_edge(clk_i) then
      --default conditions
      nan_detected(0) <= '0';
      inf_detected(0) <= '0';
      if (std_logic_vector(a_exp) = INF_OR_NAN_EXP) then
        if (std_logic_vector(a_frac) = INF_MAND) then
          inf_detected(0) <= '1';
        else
          nan_detected(0) <= '1';
        end if;
      end if;
      if (std_logic_vector(b_exp) = INF_OR_NAN_EXP) then
        if (std_logic_vector(b_frac) = INF_MAND) then
          inf_detected(0) <= '1';
        else
          nan_detected(0) <= '1';
        end if;
      end if;
      --special case where both numbers are infinity but different sign
      if (std_logic_vector(a_exp) = INF_OR_NAN_EXP) then
        if (std_logic_vector(b_exp) = INF_OR_NAN_EXP) then
          if a_sign /= b_sign then
            nan_detected(0) <= '1';
            inf_detected(0) <= '0';
          end if;
        end if;
      end if;
      nan_detected(2 downto 1) <= nan_detected(1 downto 0);
      inf_detected(2 downto 1) <= inf_detected(1 downto 0);
    end if;
  end process nan_detection;

  -- This process bitshift the smaller number so that the exponents are same
  -- This process is in the second clock cycle.
  bitshift_process : process(clk_i)
    variable a_mand_se : unsigned(24 downto 0);
    variable b_mand_se : unsigned(24 downto 0);
  begin
    if rising_edge(clk_i) then
      mod_a_bgr(1) <= mod_a_bgr(0);
      a_sign_sr(1) <= a_sign_sr(0);
      b_sign_sr(1) <= b_sign_sr(0);
      if mod_a_bgr(0) = '1' then
        a_mand_se         := unsigned(std_logic_vector(a_mand) & '0');
        b_mand_se         := unsigned(std_logic_vector(b_mand) & '0');
        a_mand_bitshifted <= a_mand_se;
        b_mand_bitshifted <= shift_right(b_mand_se,to_integer(exp_dif));
        exp_both          <= a_exp_sr;
      else
        a_mand_se         := unsigned(std_logic_vector(a_mand) & '0');
        b_mand_se         := unsigned(std_logic_vector(b_mand) & '0');
        a_mand_bitshifted <= shift_right(a_mand_se,to_integer(exp_dif));
        b_mand_bitshifted <= unsigned(std_logic_vector(b_mand) & '0');
        exp_both          <= b_exp_sr;
      end if;
    end if;
  end process bitshift_process;

  -- Sign extend so that it allows for bit growth in addition
  -- mandissa's are unsigned so just add '0' to the front
  a_mand_bitshifted_se <= unsigned('0' & std_logic_vector(a_mand_bitshifted));
  b_mand_bitshifted_se <= unsigned('0' & std_logic_vector(b_mand_bitshifted));

  -- The next process is to perform the addition or subtractions on the
  -- mandissas now that the numbers both have the same exponent.
  -- This process is in the third clock cycle.
  math_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      result_exp <= exp_both;
      if (a_sign_sr(1) = '0') and (b_sign_sr(1) = '0') then
        -- both numbers are positive and we can just add
        result_mand_unshifted <= a_mand_bitshifted_se + b_mand_bitshifted_se;
        result_sign           <= '0'; -- pos
      elsif (a_sign_sr(1) = '1') and (b_sign_sr(1) = '1') then
        -- both numbers are negative and we can just add the fractions
        -- (-a) + (-b) = - (a+b)
        result_mand_unshifted <= a_mand_bitshifted_se + b_mand_bitshifted_se;
        result_sign           <= '1'; -- neg
      elsif (mod_a_bgr(1) = '1') and (a_sign_sr(1) = '1') and (b_sign_sr(1) = '0') then
        -- a has a bigger modulus, and is negative,
        -- b is positive
        -- the result here will be a smaller negative number
        result_mand_unshifted <= a_mand_bitshifted_se - b_mand_bitshifted_se;
        result_sign           <= '1'; -- neg
      elsif (mod_a_bgr(1) = '1') and (a_sign_sr(1) = '0') and (b_sign_sr(1) = '1') then
        -- a has a bigger modulus, and is positive,
        -- b is negative
        -- the result here will be a smaller positive number
        result_mand_unshifted <= a_mand_bitshifted_se - b_mand_bitshifted_se;
        result_sign           <= '0'; -- pos
      elsif (mod_a_bgr(1) = '0') and (a_sign_sr(1) = '1') and (b_sign_sr(1) = '0') then
        -- a is negative
        -- b has a bigger modulus, and is positive,
        -- the result here will be a smaller positive number
        result_mand_unshifted <= b_mand_bitshifted_se - a_mand_bitshifted_se;
        result_sign           <= '0'; -- pos
      else --if (mod_a_bgr(1) = '0') and (a_sign_sr(1) = '0') and (b_sign_sr(1) = '1') then
        -- a is positive
        -- b has a bigger modulus, and is negative,
        -- the result here will be a smaller negative number
        result_mand_unshifted <= b_mand_bitshifted_se - a_mand_bitshifted_se;
        result_sign           <= '1'; -- neg
      end if;
    end if;
  end process math_process;

  -- This process ensures the result is in scientific notation by bitshifting
  -- ie 1.27*2^x
  -- unless the resultant number is special ie. nan, +/-inf zero, or subnormal
  -- This process is the fourth and final clock cycle
  re_normalise_proc : process(clk_i)
    constant NAN_INF_EXP     : std_logic_vector( 7 downto 0) := x"FF";
    constant NAN_MANT        : std_logic_vector(25 downto 0 ):= 26x"0000002";
    constant INF_MANT        : std_logic_vector(25 downto 0 ):= 26x"0000000";
    constant ZERO_EXP        : unsigned( 7 downto 0) := to_unsigned(0, 8);
    constant ZERO_MANT       : unsigned(25 downto 0) := to_unsigned(0,26);
    constant MAX_EXP         : std_logic_vector( 7 downto 0) := x"FE";
    constant S_NORM_MAX_MANT : std_logic_vector(25 downto 0) := 26x"0x0FFFFFE";
  begin
    if rising_edge(clk_i) then
      result_sign_final <= result_sign;
      if nan_detected(2) = '1' then
        result_exp_shifted  <= unsigned(NAN_INF_EXP);
        result_mand_shifted <= unsigned(NAN_MANT);
        result_sign_final   <= '0';
      elsif inf_detected(2) = '1' then
        result_exp_shifted  <= unsigned(NAN_INF_EXP);
        result_mand_shifted <= unsigned(INF_MANT);
      elsif result_mand_unshifted(25 downto 0) = ZERO_MANT then
        result_exp_shifted  <= ZERO_EXP;
        result_mand_shifted <= ZERO_MANT;
      elsif result_mand_unshifted(25) = '1' then
        -- bitgrowth occurred and we need to shift the exponent
        -- unless infinity was reached
        result_exp_shifted  <= result_exp + 1;
        result_mand_shifted <= shift_right(result_mand_unshifted,1);
        if MAX_EXP = std_logic_vector(result_exp) then
          result_exp_shifted  <= unsigned(NAN_INF_EXP);
          result_mand_shifted <= unsigned(INF_MANT);
        end if;
      elsif result_exp = ZERO_EXP then
        -- is a subnormal number of 0
        -- normally dont bit shift
        result_exp_shifted  <= ZERO_EXP;
        result_mand_shifted <= result_mand_unshifted;
        -- if has breaked out into normal numbers adjust accordingly
        if result_mand_unshifted(24) = '1' then
          result_exp_shifted  <= to_unsigned(1,8);
          result_mand_shifted <= result_mand_unshifted;
        end if;
      elsif result_mand_unshifted(24) = '1' then --result is 1<=X<2
        result_exp_shifted  <= result_exp;
        result_mand_shifted <= result_mand_unshifted;
      else --result_mand_unshifted(24 = '0') normal num, bitshiting required
        for i in 1 to 23 loop
          -- this checks for biggest '1's in the correct range and then
          -- bitshifts if appropriate
          if result_mand_unshifted(i) = '1' then
            -- this condition ensures that you dont shift to a exponent of -1 or
            -- a negative number
            if result_exp > 24-i then --moved into a normal number still
              result_exp_shifted  <= result_exp - (24-i);
              result_mand_shifted <= shift_left(result_mand_unshifted,24-i);
            end if;
          end if;
          if result_exp = 24-i then
              -- we have moved into a subnormal number and need to bitshift
              -- one less
              result_exp_shifted  <= result_exp - (24-i);
              result_mand_shifted <= shift_left(result_mand_unshifted,23-i);
          end if;
        end loop;
      end if;
    end if;
  end process re_normalise_proc;

  -- output mapping
  c_o(31)           <= result_sign_final;
  c_o(30 downto 23) <= std_logic_vector(result_exp_shifted);
  c_o(22 downto  0) <= std_logic_vector(result_mand_shifted(23 downto 1));

end rtl;