-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- Reusable math functions
-------------------------------------------------------------------------------

package math_utils_pkg is
  function ceil_log2(n : positive) return natural;
end package math_utils_pkg;

package body math_utils_pkg is

  function ceil_log2(n : positive) return natural is
    variable result : natural := 0;
    variable value  : positive := 1;
  begin
    if n <= 1 then
      return 0;
    end if;
    while value < n loop
      value  := value * 2;
      result := result + 1;
    end loop;
    return result;
  end function ceil_log2;

end package body math_utils_pkg;