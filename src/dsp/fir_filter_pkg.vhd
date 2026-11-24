-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- Reusable math functions
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vhdl_common;
use vhdl_common.common_types_pkg.all;

package fir_filter_pkg is
  constant RFSOC_FIR3_COEF_BITS : natural := 13;
  constant RFSOC_FIR3_TAPS      : natural := 15;
  constant RFSOC_FIR3_COEF      : array_signed_t(0 to RFSOC_FIR3_TAPS-1)(RFSOC_FIR3_COEF_BITS-1 downto 0) := 
                                 (to_signed(-6, RFSOC_FIR3_COEF_BITS),
                                  to_signed(0, RFSOC_FIR3_COEF_BITS),
                                  to_signed(54, RFSOC_FIR3_COEF_BITS),
                                  to_signed(0, RFSOC_FIR3_COEF_BITS),
                                  to_signed(-254, RFSOC_FIR3_COEF_BITS),
                                  to_signed(0, RFSOC_FIR3_COEF_BITS),
                                  to_signed(1230, RFSOC_FIR3_COEF_BITS),
                                  to_signed(2048, RFSOC_FIR3_COEF_BITS),
                                  to_signed(1230, RFSOC_FIR3_COEF_BITS),
                                  to_signed(0, RFSOC_FIR3_COEF_BITS),
                                  to_signed(-254, RFSOC_FIR3_COEF_BITS),
                                  to_signed(0, RFSOC_FIR3_COEF_BITS),
                                  to_signed(54, RFSOC_FIR3_COEF_BITS),
                                  to_signed(0, RFSOC_FIR3_COEF_BITS),
                                  to_signed(-6, RFSOC_FIR3_COEF_BITS)
                                );
    
end package fir_filter_pkg;

package body fir_filter_pkg is

end package body fir_filter_pkg;