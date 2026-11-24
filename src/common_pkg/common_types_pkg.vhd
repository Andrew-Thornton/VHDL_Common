-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
--                Common Types
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package common_types_pkg is

  type array_signed_t is array (natural range <>) of signed;
  type array_unsigned_t is array (natural range <>) of unsigned;

end package common_types_pkg;

package body common_types_pkg is


end package body common_types_pkg;