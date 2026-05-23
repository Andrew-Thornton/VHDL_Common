-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description
-- Converts an s_fixed into ieee floating point.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use ieee.fixed_float_types.all;

use work.common_float_tools_pkg.all;
use work.common_int_tools_pkg.all;

entity fixed_to_floating is
  generic(
    INT_BITS     : natural;
    FRAC_BITS    : natural
  );
  port(
    clk_i  : in  std_logic;
    srst_i : in  std_logic;
    a_i    : in  sfixed(INT_BITS-1 downto -FRAC_BITS);
    c_o    : out std_logic_vector(31 downto 0)
  );
end fixed_to_floating;

architecture rtl of fixed_to_floating is

  -- first clock cycle
  signal res_sign       : std_logic := '0';
  signal magnitude      : ufixed(INT_BITS downto -FRAC_BITS) := to_ufixed(0.0, INT_BITS, -FRAC_BITS);

  --second clock cycle
  signal res_sign_z     : std_logic := '0';
  signal magnitude_z    : ufixed(INT_BITS downto -FRAC_BITS) := to_ufixed(0.0, INT_BITS, -FRAC_BITS);
  signal left_most_one  : integer range INT_BITS-1 downto -FRAC_BITS := -FRAC_BITS;

  -- third clock cycle
  constant MANT_HIGH   : integer := integer_max(INT_BITS, 0);
  constant MANT_LOW    : integer := integer_min(-FRAC_BITS, -48);
  constant MANT_BITS   : integer := MANT_HIGH + MANT_LOW+1;
  signal res_mant      : ufixed(MANT_HIGH downto MANT_LOW)  := to_ufixed(0.0,MANT_HIGH,MANT_LOW);
  signal res_exp_slv   : std_logic_vector( 7 downto 0) := (others => '0');
  signal res_frac_slv  : std_logic_vector(22 downto 0) := (others => '0');
  signal debug_res_exp : integer range -127 to 128 := 0;
  signal res_exp       : integer range 0 to 255 := 0;
  signal res_exp_uns   : unsigned(7 downto 0) := to_unsigned(127,8);
  signal res_sign_zz   : std_logic := '0';

begin

  -- first clock cycle items convert to sign and magnitude
  invert_negative_process : process(clk_i)
    variable a_i_slv    : std_logic_vector(INT_BITS-1 + FRAC_BITS downto 0);
    variable a_i_slv_se : std_logic_vector(INT_BITS + FRAC_BITS downto 0);
    variable not_a_i_se : std_logic_vector(INT_BITS + FRAC_BITS downto 0);
    constant LSB : ufixed(INT_BITS downto -FRAC_BITS) := gen_ufixed_one_lsb(INT_BITS,-FRAC_BITS);
  begin
    if rising_edge(clk_i) then
      a_i_slv                                   := to_slv(a_i);
      a_i_slv_se(INT_BITS+FRAC_BITS-1 downto 0) := a_i_slv;
      a_i_slv_se(INT_BITS+FRAC_BITS)            := a_i_slv(INT_BITS+FRAC_BITS-1);
      if a_i(INT_BITS-1) = '0' then
        res_sign  <= '0';
        magnitude <= to_ufixed(a_i_slv_se, magnitude'high, magnitude'low);
      else
        -- if negative we negate and add 1 to covert to positive with wrap
        res_sign   <= '1';
        not_a_i_se := not(a_i_slv_se);
        magnitude <= resize(to_ufixed(not_a_i_se, magnitude'high, magnitude'low) + LSB, magnitude'high, magnitude'low, fixed_wrap, fixed_truncate);
      end if;
      if srst_i = '1' then
        res_sign  <= '0';
        magnitude <= to_ufixed(0.0, INT_BITS, -FRAC_BITS);
      end if;
    end if;
  end process;

  --second clock cycle proc
  left_most_one_and_zero_p : process(clk_i)
  begin
    if rising_edge(clk_i) then
      res_sign_z     <= res_sign;
      left_most_one  <= -FRAC_BITS;
      magnitude_z    <= magnitude;
      for i in -FRAC_BITS to INT_BITS loop
        if magnitude(i) = '1' then
          left_most_one  <= i;
        end if;
      end loop;
      if srst_i = '1' then 
        res_sign_z    <= '0';
        left_most_one <= -FRAC_BITS;
        magnitude_z   <= to_ufixed(0.0, INT_BITS, -FRAC_BITS);
      end if;
    end if;
  end process;

  -- third clock cycle
  renorm_p : process(clk_i)
    variable mag_se : ufixed(MANT_HIGH downto MANT_LOW);
  begin
    if rising_edge(clk_i) then
      -- if positive
      res_sign_zz <= res_sign_z;
      mag_se := (others => '0');
      mag_se(magnitude_z'high downto magnitude_z'low) := magnitude_z;
      if left_most_one >= 1 then
        res_mant      <= shift_right(mag_se, left_most_one);
        debug_res_exp <= left_most_one;
        res_exp       <= left_most_one+ 127;
        res_exp_uns   <= to_unsigned(left_most_one + 127,8);
      else
        res_mant      <= shift_left(mag_se, 0-left_most_one);
        debug_res_exp <= left_most_one;
        res_exp       <= left_most_one + 127;
        res_exp_uns   <= to_unsigned(left_most_one + 127,8);
      end if;
      if srst_i = '1' then
        res_sign_zz   <= '0'; 
        res_mant      <= to_ufixed(0.0,MANT_HIGH,MANT_LOW);
        debug_res_exp <= 0;       
        res_exp       <= 127;
        res_exp_uns   <= to_unsigned(127,8);      
      end if;
    end if;
  end process;

  res_exp_slv  <= std_logic_vector(res_exp_uns);
  res_frac_slv <= to_slv(res_mant(-1 downto -23));

  c_o(31)           <= res_sign_zz;
  c_o(30 downto 23) <= std_logic_vector(res_exp_uns);
  c_o(22 downto  0) <= res_frac_slv;

end rtl;