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
-- 1.0  A. Thornton   Package Creation including conversion slv -> float
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
  
end package body common_float_tools_pkg;