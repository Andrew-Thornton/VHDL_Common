-- Author        : Andrew Thornton
-- Standard      : VDHL 2008
-------------------------------------------------------------------------------

library std;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.float_pkg.all;
use ieee.fixed_pkg.all;

package common_float_tools_pkg is

  subtype slv32 is std_logic_vector(31 downto 0);

  function real_to_slv(a_i : real) return slv32;
  function slv_to_real(a_i : slv32) return real;

  function gen_ufixed_one_lsb(MSB : integer; LSB : integer) return ufixed;

end package common_float_tools_pkg;

package body common_float_tools_pkg is

  function real_to_slv(a_i : real) return slv32 is
    variable midpoint : float32;
    variable result   : slv32;
  begin
    midpoint := to_float(a_i);
    result   := to_slv(midpoint);
    return result;
  end function real_to_slv;

  function slv_to_real(a_i : slv32) return real is
    variable midpoint : float32;
    variable result : real;
  begin
    midpoint := to_float(a_i);
    result   := to_real(midpoint);
    return result;
  end function slv_to_real;

  function gen_ufixed_one_lsb(MSB : integer; LSB : integer) return ufixed is
    variable result : ufixed(MSB downto LSB);
  begin
    assert MSB>=LSB
    report "FAULT in gen_ufixed_one_lsb " 
         & "MSB<LSB"
    severity failure;
    result := (others => '0');
    result(LSB) := '1';
    return result;
  end function gen_ufixed_one_lsb;

end package body common_float_tools_pkg;