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

package common_int_tools_pkg is

  function integer_max(a, b : integer) return integer;
  function integer_min(a, b : integer) return integer;

end package common_int_tools_pkg;

package body common_int_tools_pkg is

  function integer_max(a, b : integer) return integer is
    begin
    if a > b then
        return a;
    else
        return b;
    end if;
  end function;

  function integer_min(a, b : integer) return integer is
    begin
    if a < b then
        return a;
    else
        return b;
    end if;
  end function;

end package body common_int_tools_pkg;




