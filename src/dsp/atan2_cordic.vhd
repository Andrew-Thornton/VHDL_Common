-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- Atan2 cordic
-- a cordic vectoring mode to calculate atan2.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.fixed_pkg.all;

entity atan2_cordic is
  generic(
    ITERATIONS         : positive := 16;
    INPUT_DATA_W       : positive := 16;
    OUTPUT_DATA_W      : positive := 32
  );
  port(
    clk_i   : in  std_logic;
    srst_i  : in  std_logic;
    real_i  : in  signed(INPUT_DATA_W-1 downto 0);
    imag_i  : in  signed(INPUT_DATA_W-1 downto 0);
    vld_i   : in  std_logic := '1';
    phase_o : out signed(OUTPUT_DATA_W-1 downto 0);
    vld_o   : out std_logic
  );
end atan2_cordic;

architecture rtl of atan2_cordic is
  
  type quadrant_t is (tl,tr,br,bl);
  signal quadrant : quadrant_t := tl;

  constant POS_PI : sfixed(0 downto -(OUTPUT_DATA_W-1)) :=  to_sfixed( 1.0, 0, -(OUTPUT_DATA_W-1));
  constant NEG_PI : sfixed(0 downto -(OUTPUT_DATA_W-1)) :=  to_sfixed(-1.0, 0, -(OUTPUT_DATA_W-1));

  signal real_quadrant_mod : signed(INPUT_DATA_W-1 downto 0) := (others => '0');
  signal imag_quadrant_mod : signed(INPUT_DATA_W-1 downto 0) := (others => '0');
  signal quadrant_offset   : sfixed(0 downto -(OUTPUT_DATA_W-1)) := POS_PI;
  signal vld_z             : std_logic := '0';

  type array_sfixed_out_width_t is array(natural range <>) of sfixed(0 downto -(OUTPUT_DATA_W-1));

  function gen_atan2_theta_table(iters : positive) return array_sfixed_out_width_t is
    variable theta_real  : real;
    variable theta_table : array_sfixed_out_width_t(0 to iters-1);
  begin
    for i in 0 to iters-1 loop
      theta_real := (arctan(1.0 / (2.0**i))) * MATH_1_OVER_PI;
      theta_table(i) := to_sfixed(theta_real, theta_table(i)'high, theta_table(i)'low);
    end loop;
    return theta_table;
  end function;

  constant theta_table : array_sfixed_out_width_t(0 to ITERATIONS-1) := gen_atan2_theta_table(ITERATIONS);
  signal debug_theta_table : array_sfixed_out_width_t(0 to ITERATIONS-1) := theta_table; 

  type array_signed_t is array(natural range <>) of signed;
  signal x_s : array_signed_t(0 to ITERATIONS-1)(INPUT_DATA_W-1 downto 0) := (others => (others => '0'));
  signal y_s : array_signed_t(0 to ITERATIONS-1)(INPUT_DATA_W-1 downto 0) := (others => (others => '0'));
  signal theta_s : array_sfixed_out_width_t(0 to ITERATIONS-1) := (others => (others => '0'));
  signal vld_sr : std_logic_vector(ITERATIONS downto 0) := (others => '0');

  signal quadrant_offset_sr : array_sfixed_out_width_t(0 to ITERATIONS-1) := (others => (others => '0'));
  signal quadrant_modified : sfixed(0 downto -(OUTPUT_DATA_W-1)) := (others => '0');

begin


-- The following decides which quadrant the data is in
-- and the inverts if required so that the cordic takes place only in 
-- quadrants 1 and 4 or -pi/2 < andle < pi
process(clk_i)
begin
  if rising_edge(clk_i) then
    vld_z <= vld_i;
    if real_i(INPUT_DATA_W-1) = '0' and imag_i(INPUT_DATA_W-1) = '0' then
      quadrant <= tr;
      real_quadrant_mod <= real_i;
      imag_quadrant_mod <= imag_i;
      quadrant_offset <= (others => '0');
    elsif real_i(INPUT_DATA_W-1) = '0' and imag_i(INPUT_DATA_W-1) = '1' then
      quadrant <= br;
      real_quadrant_mod <= real_i;
      imag_quadrant_mod <= imag_i;
      quadrant_offset   <= (others => '0');
    elsif real_i(INPUT_DATA_W-1) = '1' and imag_i(INPUT_DATA_W-1) = '0' then
      quadrant <= tl;
      real_quadrant_mod <= 0-real_i; -- need to clip somehow here
      imag_quadrant_mod <= 0-imag_i; -- need to clip somehow here
      quadrant_offset   <= POS_PI;
    else --real_i(INPUT_DATA_W-1) = '1' and imag_i(INPUT_DATA_W-1) = '1' then
      quadrant <= bl;
      real_quadrant_mod <= 0-real_i; -- need to clip somehow here
      imag_quadrant_mod <= 0-imag_i; -- need to clip somehow here
      quadrant_offset   <= NEG_PI;
    end if;
  end if;
end process;

process(clk_i)
begin
  if rising_edge(clk_i) then
    vld_sr(0) <= vld_z;
    vld_sr(ITERATIONS downto 1) <= vld_sr(ITERATIONS-1 downto 0);
    quadrant_offset_sr(0) <= quadrant_offset;
    quadrant_offset_sr(1 to ITERATIONS-1) <= quadrant_offset_sr(0 to ITERATIONS-2);

    x_s(0) <= real_quadrant_mod;
    y_s(0) <= imag_quadrant_mod;
    theta_s(0) <= (others => '0');

    for iter in 1 to ITERATIONS-1 loop
      if y_s(iter-1) > 0 then
        theta_s(iter) <= resize(theta_s(iter-1) + theta_table(iter-1), theta_s(iter)'high,theta_s(iter)'low);
        x_s(iter) <= x_s(iter-1) + shift_right(y_s(iter-1),iter-1);
        y_s(iter) <= y_s(iter-1) - shift_right(x_s(iter-1),iter-1);
      else
        theta_s(iter) <= resize(theta_s(iter-1) - theta_table(iter-1), theta_s(iter)'high,theta_s(iter)'low);
        x_s(iter) <= x_s(iter-1) - shift_right(y_s(iter-1),iter-1);
        y_s(iter) <= y_s(iter-1) + shift_right(x_s(iter-1),iter-1);
      end if;

    end loop;

    -- add the offset if required to extend the range from -pi/2 /pi/2 to -pi=>pi
    quadrant_modified <= resize(theta_s(ITERATIONS-1) + quadrant_offset_sr(ITERATIONS-1),quadrant_modified'high,quadrant_modified'low);

  end if;
end process;

-- change later
phase_o <= signed(to_slv(quadrant_modified));
vld_o   <= vld_sr(ITERATIONS);

end rtl;
