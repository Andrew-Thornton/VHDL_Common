-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Creation Date : 2025-Oct-01
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Rev  Author       Date        Description
-- 0.0  A. Thornton  2025-OCT-01 WIP
-------------------------------------------------------------------------------
-- Description
-- This module performs a multiplication of 2 numbers which comply with
-- IEEE-754 Floating Point
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity float_mult is
  port(
    clk_i  : in  std_logic;
    srst_i : in  std_logic;
    a_i    : in  std_logic_vector(31 downto 0);
    b_i    : in  std_logic_vector(31 downto 0);
    c_o    : out std_logic_vector(31 downto 0)
  );
end float_mult;

architecture rtl of float_mult is

  --breaking up the inputs into the respective parts
  signal a_sign   : std_logic := '0';
  signal b_sign   : std_logic := '0';
  signal a_exp    : unsigned( 7 downto 0) := (others => '0');
  signal b_exp    : unsigned( 7 downto 0) := (others => '0');
  signal a_frac   : unsigned(22 downto 0) := (others => '0');
  signal b_frac   : unsigned(22 downto 0) := (others => '0');

  -- 1st clock cycle signals
  signal res_sign : std_logic := '0';
  signal a_exp_sr : unsigned( 7 downto 0) := (others => '0');
  signal b_exp_sr : unsigned( 7 downto 0) := (others => '0');
  signal a_mant   : unsigned(23 downto 0) := (others => '0'); -- 1 uint and 23 frac
  signal b_mant   : unsigned(23 downto 0) := (others => '0'); -- 1 uint and 23 frac
  signal inf_det  : std_logic := '0';
  signal nan_det  : std_logic := '0';
  signal zero_det : std_logic := '0';
  --debug
  signal debug_a_exp : integer;
  signal debug_b_exp : integer;

  -- 2nd and 3rd clock cycle multiplier signals
  signal res_mant1 : unsigned(47 downto 0) := (others => '0');
  signal res_mant  : unsigned(47 downto 0) := (others => '0');

  -- 2nd and 3rd clock cycle exponent signals
  signal res_exp_nbs              : unsigned(8 downto 0) := to_unsigned(0,9);
  signal maybe_shift_right_amount : unsigned(8 downto 0) := to_unsigned(0,9);
  signal subnormal_shift_right    : std_logic := '0';
  signal res_exp_norm_nbs         : unsigned(9 downto 0) := to_unsigned(127,10);
  signal is_max_exp               : std_logic := '0';
  signal is_one_below_max_exp     : std_logic := '0';

  -- 2nd to 3rd clock cycle shift register signals
  signal res_sign_z   : std_logic := '0';
  signal res_sign_zz  : std_logic := '0';
  signal inf_det_z    : std_logic := '0';
  signal inf_det_zz   : std_logic := '0';
  signal nan_det_z    : std_logic := '0';
  signal nan_det_zz   : std_logic := '0';
  signal zero_det_z   : std_logic := '0';
  signal zero_det_zz  : std_logic := '0';
  signal shift_right_amount : unsigned(8 downto 0) := to_unsigned(0,9); -- TODO check bit width

  --4th clock cycle bitshifted signals
  signal exp_shifted_right      : unsigned( 9 downto 0) := (others => '0');
  signal mant_shifted_right     : unsigned(55 downto 0) := (others => '0'); --2 int 46 frac
  signal res_exp_norm_nbs_z     : unsigned(9 downto 0) := to_unsigned(127,10);
  signal is_max_exp_z           : std_logic := '0';
  signal is_one_below_max_exp_z : std_logic := '0';
  signal res_is_subnormal       : std_logic := '0';

  signal res_sign_zzz       : std_logic := '0';
  signal inf_det_zzz        : std_logic := '0';
  signal nan_det_zzz        : std_logic := '0';
  signal zero_det_zzz       : std_logic := '0';

  --5th clock cycle items
  signal exp_shifted_right_norm  : unsigned(9 downto 0) := to_unsigned(0,10);
  signal mant_shifted_right_norm : unsigned(55 downto 0) := to_unsigned(0,56);
  signal shift_left_req          : std_logic := '0';
  signal shift_left_amount       : unsigned(5 downto 0) := (others => '0');
  signal res_sign_zzzz           : std_logic := '0';
  signal inf_det_zzzz            : std_logic := '0';
  signal nan_det_zzzz            : std_logic := '0';
  signal zero_det_zzzz           : std_logic := '0';
  signal dbg_shift_right_option  : integer   := 0;

  --6th clock cycle items
  signal exp_shifted_left   : unsigned( 9 downto 0) := (others => '0');
  signal mant_shifted_left  : unsigned(47 downto 0) := (others => '0'); --2 int 46 frac
  signal res_sign_zzzzz     : std_logic := '0';
  signal inf_det_zzzzz      : std_logic := '0';
  signal nan_det_zzzzz      : std_logic := '0';
  signal zero_det_zzzzz     : std_logic := '0';

  --7th clock cycle items
  signal res_final         : std_logic := '0';
  signal exp_final         : unsigned( 7 downto 0) := (others => '0');
  signal mant_final        : unsigned(22 downto 0) := (others => '0');

begin

  -- input mapping
  a_sign <= a_i(31);
  b_sign <= b_i(31);
  a_exp  <= unsigned(a_i(30 downto 23));
  b_exp  <= unsigned(b_i(30 downto 23));
  a_frac <= unsigned(a_i(22 downto  0));
  b_frac <= unsigned(b_i(22 downto  0));
  ---------------------------------------------------------------------------
  -- clock cycle 1 items
  -- This process adds the missing MSB to the mantissa depending on whether the
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
        a_mant <= unsigned('0' & std_logic_vector(a_frac)); -- subnorm or zero
      else
        a_mant <= unsigned('1' & std_logic_vector(a_frac)); -- normal
      end if;
      if (std_logic_vector(b_exp) = EXP_ZEROS) then
        b_mant <= unsigned('0' & std_logic_vector(b_frac)); -- subnorm or zero
      else
        b_mant <= unsigned('1' & std_logic_vector(b_frac)); -- normal
      end if;
      if srst_i = '1' then
        a_mant <= to_unsigned(0,24);
        b_mant <= to_unsigned(0,24);
      end if;
    end if;
  end process zero_or_non_zero_select;

  -- This is part of the first clock cycle process and determines if
  -- the result is going to be positive or negative.
  result_sign_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
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
      debug_a_exp      <= to_integer(a_exp) - 127;
      debug_b_exp      <= to_integer(b_exp) - 127;                                                                                    
      if srst_i = '1' then                                                      
        a_exp_sr <= to_unsigned(0,8);                                              
        b_exp_sr <= to_unsigned(0,8);                                               
      end if;                                                           
    end if;                                             
  end process shift_register_proc;
  
  -- This process just shift registers the exponents for now
  -- this is first clock cycle 
  inf_and_nan_detection : process(clk_i)
    constant INF_OR_NAN_EXP : std_logic_vector( 7 downto 0) := x"FF";
    constant SUB_NORM_EXP   : std_logic_vector( 7 downto 0) := x"00";
    constant INF_MANT       : std_logic_vector(22 downto 0) := 23x"000000";
    constant ZERO_MANT      : std_logic_vector(22 downto 0) := 23x"000000";
  begin
    if rising_edge(clk_i) then
      nan_det   <= '0';
      inf_det   <= '0';
      zero_det  <= '0';
      if (std_logic_vector(a_exp) = INF_OR_NAN_EXP) then
        if (std_logic_vector(a_frac) = INF_MANT) then
          inf_det <= '1';
        else
          nan_det <= '1';
        end if;
      end if;
      if (std_logic_vector(b_exp) = INF_OR_NAN_EXP) then
        if (std_logic_vector(b_frac) = INF_MANT) then
          inf_det <= '1';
        else
          nan_det <= '1';
        end if;
      end if;
      if (std_logic_vector(b_exp) = SUB_NORM_EXP) then
        if (std_logic_vector(b_frac) = INF_MANT) then
          zero_det <= '1';
        end if;
      end if;
      if (std_logic_vector(a_exp) = SUB_NORM_EXP) then
        if (std_logic_vector(a_frac) = INF_MANT) then
          zero_det <= '1';
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
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
      res_mant1 <= a_mant * b_mant; -- 1 int 23 frac * 1 int 23 frac = 2int 46 frac 
      res_mant  <= res_mant1;
      if srst_i = '1' then
        res_mant1 <= to_unsigned(0,48);
        res_mant  <= to_unsigned(0,48); --2 int 46 frac
      end if;
    end if;
  end process multiplier_process;

  -- This takes two clock cycles 2 and 3 and only takes this long
  -- as the multiplier is the bottle neck
  -- for a numbers in the format (1.a * 2^b) * (1.c * 2^d)
  -- the result is 1.aa*1.cc * (2^b+d)
  -- This is doing the b+d
  -- Note when we have effectively added the first digit in the mant
  -- we have effectively taken car of subnormal numbers.
  -- Furtherermore b and d here are exp-127
  -- so (exp-127) + (exp -127) is result_exp-127 -127
  -- so we need to add 127 to the number
  -- This is the exponent calculation stage
  exponent_res_pre_shift_process : process(clk_i)
    constant MAX_EXP          : std_logic_vector( 9 downto 0) := 10x"17E"; --382 = 255+127 = 0x17E
    constant ONE_LESS_MAX_EXP : std_logic_vector( 9 downto 0) := 10x"17D"; --381 = 254+127 = 0x17D
  begin
    if rising_edge(clk_i) then
      res_exp_nbs      <= ('0' & a_exp_sr) + ('0' & b_exp_sr); 
      maybe_shift_right_amount <= to_unsigned(128,9) - res_exp_nbs;
      -- I expect this to need bitshifting for cases where we have entered sub normal
      -- need to add test
      -- if res_exp_nbs > to_unsigned(127,9) then
      if res_exp_nbs(8)= '1' or res_exp_nbs(7) = '1' then
        res_exp_norm_nbs       <= ('0' & res_exp_nbs) - to_unsigned(127,10);
        subnormal_shift_right  <= '0';
      else
        res_exp_norm_nbs       <= to_unsigned(0,10);
        subnormal_shift_right  <= '1';
      end if;

      is_max_exp <= '0';
      if res_exp_nbs = unsigned(MAX_EXP) then
        is_max_exp <= '1';
      end if;

      is_one_below_max_exp <= '0';
      if res_exp_nbs = unsigned(ONE_LESS_MAX_EXP) then
        is_one_below_max_exp <= '1';
      end if;

      if srst_i = '1' then
        res_exp_norm_nbs <= to_unsigned(0,10);
        subnormal_shift_right <= '0';
      end if;
    end if;
  end process exponent_res_pre_shift_process;

  -- Clock cycles 2 and 3
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
      zero_det_z   <= zero_det;
      zero_det_zz  <= zero_det_z;
      if srst_i = '1' then
        res_sign_z   <= '0';
        res_sign_zz  <= '0';
        inf_det_z    <= '0';
        inf_det_zz   <= '0';
        nan_det_z    <= '0';
        nan_det_zz   <= '0';
        zero_det_z   <= '0';
        zero_det_zz  <= '0';
      end if;
    end if;
  end process shift_register_procs;

  ---------------------------------------------------------------------------

  -- The 4th clock cycle is re bitshifting in case of
  -- mantissa overflow or underflow
  how_much_shift_subnormal_proc : process(clk_i)
    variable larger_mant_shit : std_logic_vector(55 downto 0);
  begin
    if rising_edge(clk_i) then
      larger_mant_shit       := std_logic_vector(res_mant) & "00000000";--48 bits -> 56 bits
      mant_shifted_right     <= unsigned(larger_mant_shit);
      res_is_subnormal       <= subnormal_shift_right;
      is_max_exp_z           <= is_max_exp;
      is_one_below_max_exp_z <= is_one_below_max_exp;
      if subnormal_shift_right = '1' then
        mant_shifted_right <= shift_right(unsigned(larger_mant_shit), to_integer(maybe_shift_right_amount));
      end if;
    end if;
  end process;

  --just shift register for the fourth clock cycle
  shift_register_procs_cc4 : process(clk_i)
  begin
    if rising_edge(clk_i) then
      res_exp_norm_nbs_z <= res_exp_norm_nbs;
      res_sign_zzz <= res_sign_zz;
      inf_det_zzz  <= inf_det_zz;
      nan_det_zzz  <= nan_det_zz;
      zero_det_zzz <= zero_det_zz;
      if srst_i = '1' then
        res_sign_zzz <= '0';
        inf_det_zzz  <= '0';
        nan_det_zzz  <= '0';
        zero_det_zzz <= '0';
      end if;
    end if;
  end process shift_register_procs_cc4;

  ---------------------------------------------------------------------------

  -- The 5th clock cycle is shifting the mantissa right if the result
  -- and changing the power of 2 if the result is not in the 
  -- range of 1<=X<2 for a normal number
  -- or 0<=X<1 for a subnormal number
  shift_right_proc : process(clk_i)
    constant NAN_INF_EXP     : std_logic_vector( 9 downto 0) := 10x"3FF";
    constant NAN_MANT        : std_logic_vector(55 downto 0 ):= x"00000080000000";
    constant INF_MANT        : std_logic_vector(55 downto 0 ):= x"00000000000000";
    constant ZERO_EXP        : unsigned( 9 downto 0) := to_unsigned(0, 10);
    constant ZERO_MANT       : unsigned(47 downto 0) := to_unsigned(0,48);
    constant MAX_EXP         : std_logic_vector( 9 downto 0) := 10x"0FE";
  begin
    if rising_edge(clk_i) then
      shift_left_req     <= '0';
      dbg_shift_right_option <= 0;
      if ( (mant_shifted_right(55) = '1' or mant_shifted_right(54) = '1') and is_max_exp_z = '1' )
      or ( (mant_shifted_right(55) = '1' and is_one_below_max_exp_z = '1' ) ) then
        -- this case the result is already at the maximum exponent
        -- and will cause an overflow into +/- infinity
        exp_shifted_right_norm  <= unsigned(NAN_INF_EXP);
        mant_shifted_right_norm <= unsigned(INF_MANT);   
        dbg_shift_right_option  <= 1;
      elsif mant_shifted_right(55) = '1' and is_max_exp_z = '0' and res_is_subnormal = '0' then
        -- the result is when the mantissa is between 2<=X<4
        -- and we shift right to divide by 2, and increase the exponent by 1
        exp_shifted_right_norm  <= res_exp_norm_nbs_z + 1;
        mant_shifted_right_norm <= shift_right(mant_shifted_right,1);
        dbg_shift_right_option <= 2;
      elsif mant_shifted_right(55) = '1' and res_is_subnormal = '1' then
        -- This result is when the result is between 2<X<4 and the exponent
        -- is currently subnormal, the mantissa is divided by two
        -- and the number is back in the normal range
        exp_shifted_right_norm  <= res_exp_norm_nbs_z + 1;
        mant_shifted_right_norm <= shift_right(mant_shifted_right,1);
        dbg_shift_right_option <= 3;
      elsif mant_shifted_right(54) = '1' and res_is_subnormal = '1' then
        -- This is when the number is 1<=X<2 but the exponent is signalling subnormal
        -- The exponent is increased (to 1)
        -- the mantissa is left how it is, because the two too bits will just be cropped
        -- off with the result, but 
        exp_shifted_right_norm  <= to_unsigned(1,10);
        mant_shifted_right_norm <= mant_shifted_right;
        dbg_shift_right_option <= 4;
      elsif mant_shifted_right(54) = '0' and res_is_subnormal = '1' then
        -- result stays subnormal, still has mantissa X<1
        exp_shifted_right_norm  <= ZERO_EXP;
        mant_shifted_right_norm <= mant_shifted_right;
        dbg_shift_right_option <= 5;
      elsif mant_shifted_right(54) = '1' and res_is_subnormal = '0' then 
        shift_left_req          <= '0';
        exp_shifted_right_norm  <= res_exp_norm_nbs_z;
        mant_shifted_right_norm <= mant_shifted_right;
        dbg_shift_right_option <= 6;
      else --mant_shifted_right(55) = '0' and res_mant(54) = '0' and res_is_subnormal = '0' then
        -- This is the case when the X<1 but the exponent is in normal range
        -- we need to multiply by 2,4,8 so that the mantissa is back 
        -- within normal ranges
        shift_left_req          <= '1';
        exp_shifted_right_norm  <= res_exp_norm_nbs_z;
        mant_shifted_right_norm <= mant_shifted_right;
        dbg_shift_right_option <= 7;
      end if;

      if srst_i = '1' then
        shift_left_req     <= '0';
        exp_shifted_right_norm  <= to_unsigned(0,10);
        mant_shifted_right_norm <= to_unsigned(0,56);
        dbg_shift_right_option <= 8;
      end if;
    end if;
  end process;

  -- Fifth Clock Cycle
  -- This process looks at the mantissa, and then determines the position of
  -- the leftmost bit, this is then used in the shift right process
  -- no reset required for this signal as shift_left_req  is reset to '0'
  find_left_most_bit_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      shift_left_amount  <= to_unsigned(0,6);
      for i in 1 to 46 loop
        if mant_shifted_right(i) = '1' then
          shift_left_amount  <= to_unsigned(55,6) - to_unsigned(i,6);
        end if;
      end loop;
    end if;
  end process find_left_most_bit_process;

  --just shift register for the fifth clock cycle
  shift_register_procs_cc5 : process(clk_i)
  begin
    if rising_edge(clk_i) then
      res_sign_zzzz  <= res_sign_zzz;
      inf_det_zzzz   <= inf_det_zzz;
      nan_det_zzzz   <= nan_det_zzz;
      zero_det_zzzz  <= zero_det_zzz;
      if srst_i = '1' then
        res_sign_zzzz <= '0';
        inf_det_zzzz  <= '0';
        nan_det_zzzz  <= '0';
        zero_det_zzzz <= '0';
      end if;
    end if;
  end process shift_register_procs_cc5;

  ---------------------------------------------------------------------------

  -- Sixth clock cycle bitshifting the result to the right
  bitshift_left_process : process(clk_i)
    constant NAN_INF_EXP     : std_logic_vector( 9 downto 0) := 10x"3FF";
    constant INF_MANT        : std_logic_vector(47 downto 0 ):= x"000000000000";
    variable mant_shifted_left_fs : unsigned(55 downto 0);
  begin
    if rising_edge(clk_i) then
      if shift_left_req  = '1' then
        if to_integer(shift_left_amount) = 0 then
          exp_shifted_left  <= to_unsigned(0,10); --ERROR STATE should never occur, remove after sim
          mant_shifted_left_fs := to_unsigned(0,56); --ERROR STATE should never occur, remove after sim
        elsif (to_integer(exp_shifted_right_norm) > shift_left_amount ) then
          -- moved into a normal number still
          exp_shifted_left  <= exp_shifted_right_norm - shift_left_amount ;
          mant_shifted_left_fs := shift_left(mant_shifted_right_norm, to_integer(shift_left_amount));
        elsif (to_integer(exp_shifted_right_norm) = shift_left_amount ) then
          -- we have moved into a subnormal number and need to bitshift
          -- one less
          exp_shifted_left  <= to_unsigned(0,10);
          mant_shifted_left_fs := shift_left(mant_shifted_right_norm, to_integer(shift_left_amount) - 1);
        else
          -- maximum bit shift we can do, but has entered subnormal range
          -- one less as has entered subnormla
          exp_shifted_left  <= to_unsigned(0,10);
          mant_shifted_left_fs := shift_left(mant_shifted_right_norm, to_integer(exp_shifted_right_norm)-1);
        end if;
      else -- shift_left_req  = '0' then
        exp_shifted_left     <= exp_shifted_right_norm;
        mant_shifted_left_fs := mant_shifted_right_norm;
        if exp_shifted_right_norm>to_unsigned(254,10) then
          exp_shifted_left  <= unsigned(NAN_INF_EXP); 
          mant_shifted_left <= unsigned(INF_MANT);
        end if;
      end if;
      mant_shifted_left <= mant_shifted_left_fs(55 downto 8);
      if srst_i = '1' then
        exp_shifted_left  <= to_unsigned(0,10);
        mant_shifted_left <= to_unsigned(0,48);
      end if;
    end if;
  end process bitshift_left_process;

  --just shift register for the fifth clock cycle
  shift_register_procs_cc6 : process(clk_i)
  begin
    if rising_edge(clk_i) then
      res_sign_zzzzz  <= res_sign_zzzz;
      inf_det_zzzzz   <= inf_det_zzzz;
      nan_det_zzzzz   <= nan_det_zzzz;
      zero_det_zzzzz  <= zero_det_zzzz;
      if srst_i = '1' then
        res_sign_zzzzz <= '0';
        inf_det_zzzzz  <= '0';
        nan_det_zzzzz  <= '0';
        zero_det_zzzzz <= '0';
      end if;
    end if;
  end process shift_register_procs_cc6;

  -- 7th clock cycle checks to make sure the nans and infs have been detected accordingly
  process_final_checks : process(clk_i)
    constant ZERO_EXP        : std_logic_vector( 7 downto 0) := x"00";
    constant ZERO_MANT       : std_logic_vector(22 downto 0) := "000" & x"00000";
    constant NAN_INF_EXP     : std_logic_vector( 7 downto 0) := x"FF";
    constant NAN_MANT        : std_logic_vector(22 downto 0 ):= "000" & x"00001";
    constant INF_MANT        : std_logic_vector(22 downto 0 ):= "000" & x"00000";
  begin
    if rising_edge(clk_i) then
      res_final <= res_sign_zzzzz;
      exp_final <= exp_shifted_left(7 downto 0);
      mant_final <= mant_shifted_left(45 downto 23);
      if nan_det_zzzzz = '1' then
        exp_final  <= unsigned(NAN_INF_EXP);
        mant_final <= unsigned(NAN_MANT);
        res_final  <= '0';
      elsif zero_det_zzzzz = '1' and inf_det_zzzzz = '1' then
        exp_final  <= unsigned(NAN_INF_EXP);
        mant_final <= unsigned(NAN_MANT);
        res_final  <= '0';
      elsif zero_det_zzzzz = '1' then
        exp_final  <= unsigned(ZERO_EXP);
        mant_final <= unsigned(ZERO_MANT);
        res_final  <= '0';
      elsif inf_det_zzzzz = '1' then
        exp_final  <= unsigned(NAN_INF_EXP);
        mant_final <= unsigned(INF_MANT);
      end if;
    end if;
  end process;

  -- output mapping
  c_o(31)           <= res_final;
  c_o(30 downto 23) <= std_logic_vector(exp_final);
  c_o(22 downto  0) <= std_logic_vector(mant_final);

end rtl;