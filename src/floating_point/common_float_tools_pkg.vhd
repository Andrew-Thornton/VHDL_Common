-- Author        : Andrew Thornton
-- Standard      : VDHL 2008
-------------------------------------------------------------------------------

library std;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.float_pkg.all;


package common_float_tools_pkg is

  subtype slv32 is std_logic_vector(31 downto 0);

  function real_to_slv(a_i : real) return slv32;
  function slv_to_real(a_i : slv32) return real;

end package common_float_tools_pkg;

package body common_float_tools_pkg is

  function real_to_slv(a_i : real) return slv32 is
    variable midpoint : float32;
    variable result   : slv32;
  begin
    midpoint := to_float(a_i);
    result   := to_slv(midpoint);
    return result;
  end;

  function slv_to_real(a_i : slv32) return real is
    variable midpoint : float32;
    variable result : real;
  begin
    midpoint := to_float(a_i);
    result   := to_real(midpoint);
    return result;
  end;

end package body common_float_tools_pkg;