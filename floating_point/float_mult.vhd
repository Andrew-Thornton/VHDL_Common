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
  signal inf_det : std_logic;
  signal nan_det : std_logic;

  -- 2nd and 3rd clock cycle multiplier signals
  signal res_mand1 : unsigned(47 downto 0);
  signal res_mand  : unsigned(47 downto 0);

  -- 2nd and 3rd clock cycle exponent signals
  signal a_exp_sr1   : unsigned( 7 downto 0);
  signal b_exp_sr1   : unsigned( 7 downto 0);
  signal res_exp_nbs : unsigned( 8 downto 0);
  signal res_exp_norm_nbs : unsigned(9 downto 0);

  -- 2nd to 3rd clock cycle shift register signals
  signal res_sign_z   : std_logic;
  signal res_sign_zz  : std_logic;
  signal inf_det_z    : std_logic;
  signal inf_det_zz   : std_logic;
  signal nan_det_z    : std_logic;
  signal nan_det_zz   : std_logic;

  --4th clock cycle bitshifted signals
  signal res_mand_bs : std_logic_vector(23 downto 0);
  signal res_exp_bs  : unsigned( 8 downto 0);
  signal exp_shifted_right : unsigned(46 downto 0);
  signal mand_shifted_right : unsigned(46 downto 0);

  signal res_sign_zzz : std_logic;

begin

  -- input mapping
  a_sign <= a_i(31);
  b_sign <= b_i(31);
  a_exp  <= unsigned(a_i(30 downto 23));
  b_exp  <= unsigned(b_i(30 downto 23));
  a_frac <= unsigned(a_i(22 downto  0));
  b_frac <= unsigned(b_i(22 downto  0));

  -- clock cycle 1 items
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

  inf_and_nan_detection : process(clk_i)
    constant INF_OR_NAN_EXP : std_logic_vector( 7 downto 0) := x"FF";
    constant SUB_NORM_EXP   : std_logic_vector( 7 downto 0) := x"00";
    constant INF_MAND       : std_logic_vector(22 downto 0) := 23x"000000";
  begin
    nan_det   <= '0';
    inf_det   <= '0';
    if rising_edge(clk_i) then
      if (std_logic_vector(a_exp) = INF_OR_NAN_EXP) then
        if (std_logic_vector(a_frac) = INF_MAND) then
          inf_det <= '1';
        else
          nan_det <= '1';
        end if;
      end if;
      if (std_logic_vector(b_exp) = INF_OR_NAN_EXP) then
        if (std_logic_vector(b_frac) = INF_MAND) then
          inf_det <= '1';
        else
          nan_det <= '1';
        end if;
      end if;
    end if;
  end process;

  -- Clock cycles 2 and 3 items

  -- for a numbers in the format (1.a * 2^b) * (1.c * 2^d)
  -- the result is 1.aa*1.cc * (2^b+d)
  -- This is doing the 1.aa*1.cc
  -- but notes this could be normal or subnormal
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
  end process multiplier_process;

  -- This takes two clock cycles 2 and 3 and only takes this long
  -- as the multiplier is the bottle neck
  -- for a numbers in the format (1.a * 2^b) * (1.c * 2^d)
  -- the result is 1.aa*1.cc * (2^b+d)
  -- This is doing the b+d
  -- Note when we have effectively added the first digit in the mand
  -- we have effectively taken car of subnormal numbers.
  -- Furtherermore b and d here are exp-127
  -- so (exp-127) + (exp -127) is result_exp-127 -127
  -- so we need to add 127 to the number
  -- This is the exponent calculation stage
  exponent_res_pre_shift_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      res_exp_nbs      <= a_exp_sr + b_exp_sr;
      res_exp_norm_nbs <= res_exp_nbs + 127;
      if srst_i = '1' then
        res_exp_nbs      <= to_unsigned(0,9);
        res_exp_norm_nbs <= to_unsigned(0,10);
      end if;
    end if;
  end process exponent_res_pre_shift_process;

  -- We have already calculated what the result sign will be
  -- so just delay this so it is in sync with the output
  -- at the end.
  shift_register_procs : process(clk_i)
  begin
    if rising_edge(clk_i) then
      res_sign_z   <= res_sign;
      res_sign_zz  <= res_sign_z;
      inf_det_z    <= inf_det;
      inf_det_zz   <= inf_det_z;
      nan_det_z    <= nan_det;
      nan_det_zz   <= nan_det_z;
      if srst_i = '1' then
        res_sign_z   <= '0';
        res_sign_zz  <= '0';
        inf_det_z    <= '0';
        inf_det_zz   <= '0';
        nan_det_z    <= '0';
        nan_det_zz   <= '0';
      end if;
    end if;
  end process shift_register_procs;

  -- The 4th clock cycle is re bitshifting in case of
  -- mandissa overflow or underflow
  -- note more to this here, andrew check soon, but need to make sure that we account for subnormal numbers
  renorm_process : process(clk_i)
    constant NAN_INF_EXP     : std_logic_vector( 7 downto 0) := x"FF";
    constant NAN_MANT        : std_logic_vector(25 downto 0 ):= 26x"0000002";
    constant INF_MANT        : std_logic_vector(25 downto 0 ):= 26x"0000000";
    constant ZERO_EXP        : unsigned( 7 downto 0) := to_unsigned(0, 8);
    constant ZERO_MANT       : unsigned(47 downto 0) := to_unsigned(0,26);
    constant MAX_EXP         : std_logic_vector( 7 downto 0) := x"FE";
    constant S_NORM_MAX_MANT : std_logic_vector(47 downto 0) := 26x"0FFFFFE";

    constant MAND_2_0 : std_logic_vector(23 downto 0) := "100000000000000000000000"; --2 int 46 frac
    constant MAND_1_0 : std_logic_vector(23 downto 0) := "010000000000000000000000"; --2 int 46 frac
  begin
    if rising_edge(clk_i) then
      if rising_edge(clk_i) then
        res_sign_zzz    <= res_sign_zz;
        shift_left_req  <= '0';
        if nan_det_zz = '1' then
           exp_shifted_right  <= unsigned(NAN_INF_EXP);
           mand_shifted_right <= unsigned(NAN_MANT);
           result_sign_four    <= '0';
        elsif inf_det_zz = '1' then
           exp_shifted_right  <= unsigned(NAN_INF_EXP);
           mand_shifted_right <= unsigned(INF_MANT);
        elsif res_mand(47) = '1' then
          -- bitgrowth occurred and we need to shift the exponent
          -- unless infinity was reached
          exp_shifted_right  <= res_exp_norm_nbs + 1;
          mand_shifted_right <= shift_right(res_mand,1);
          if MAX_EXP = std_logic_vector(res_exp_norm_nbs) then
            exp_shifted_right  <= unsigned(NAN_INF_EXP);
            mand_shifted_right <= unsigned(INF_MANT);
          end if;
        elsif res_exp_norm_nbs = ZERO_EXP then
          -- is a subnormal number of 0
          -- normally dont bit shift
          exp_shifted_right  <= ZERO_EXP;
          mand_shifted_right <= res_mand;
          -- if has breaked out into normal numbers adjust accordingly
          if res_mand(46) = '1' then
            exp_shifted_right  <= to_unsigned(1,8);
            mand_shifted_right <= res_mand;
          end if;
        elsif res_mand(46) = '1' then --result is 1<=X<2
          exp_shifted_right  <= result_exp;
          mand_shifted_right <= res_mand;
        else --res_mand(46) = '0' normal num, bitshiting required
          shift_left_req     <= '1';
          exp_shifted_right  <= result_exp;
          mand_shifted_right <= res_mand;
        end if;
        if srst_i = '1' then
          shift_left_req     <= '0';
          res_sign_zzz       <= '0';
          exp_shifted_right  <= to_unsigned(0,8);
          mand_shifted_right <= to_unsigned(0,26);
        end if;
      end if;
    end if;
  end process renorm_process;

  -- This process looks at the mandissa, and then determines the position of
  -- the leftmost bit, this is then used in the shift right process
  -- This is in the fourth clock cycle
  -- no reset required for this signal as shift_left_req  is reset to '0'
  find_left_most_bit_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      shift_left_amount  <= 0;
      for i in 1 to 46 loop
        if res_mand(i) = '1' then
          shift_left_amount  <= 47-i;
        end if;
      end loop;
    end if;
  end process find_left_most_bit_process;

    -- fifth clock cycle bitshifting the result to the right
  bitshift_left_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      result_sign_five <= result_sign_four;
      if shift_left_req  = '1' then
        if (to_integer(exp_shifted_right) > shift_left_amount ) then
          -- moved into a normal number still
          exp_shifted_left  <= exp_shifted_right - shift_left_amount ;
          mand_shifted_left <= shift_left(mand_shifted_right, shift_left_amount );
        elsif (to_integer(exp_shifted_right) = shift_left_amount ) then
          -- we have moved into a subnormal number and need to bitshift
          -- one less
          exp_shifted_left  <= to_unsigned(0,8);
          mand_shifted_left <= shift_left(mand_shifted_right, shift_left_amount -1);
        else
          -- maximum bit shift we can do, but has entered subnormal range
          -- one less as has entered subnormla
          exp_shifted_left  <= to_unsigned(0,8);
          mand_shifted_left <= shift_left(mand_shifted_right, to_integer(exp_shifted_right)-1);
        end if;
      else -- shift_left_req  = '0' then
        exp_shifted_left  <= exp_shifted_right;
        mand_shifted_left <= mand_shifted_right;
      end if;
      if srst_i = '1' then
        result_sign_five  <= '0';
        exp_shifted_left  <= to_unsigned(0,8);
        mand_shifted_left <= to_unsigned(0,26);
      end if;
    end if;
  end process bitshift_left_process;

  -- output mapping
  c_o(31)           <= res_sign_zzz;
  c_o(30 downto 23) <= std_logic_vector(res_exp_bs(8 downto 0));
  c_o(22 downto  0) <= std_logic_vector(res_mand_bs(23 downto 1));

end rtl;