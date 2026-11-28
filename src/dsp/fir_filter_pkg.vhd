-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- FIR filter coefficient sets
--
-- RFSOC_* sets are the RF-ADC decimation half-band filters from AMD PG269
-- (Zynq UltraScale+ RFSoC RF Data Converter, Gen 3/DFE). For each set the
-- coefficients sum to 2**<name>_GAIN_BITS, so shifting the filter output right
-- by <name>_GAIN_BITS gives unity DC gain.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vhdl_common;
use vhdl_common.common_types_pkg.all;

package fir_filter_pkg is

  -- PG269 Gen 3/DFE RF-ADC FIR1a, 2x decimation half-band
  -- (centre tap 65536, coefficients sum to 2**17)
  constant RFSOC_FIR1A_COEF_BITS : natural := 18;
  constant RFSOC_FIR1A_TAPS      : natural := 59;
  constant RFSOC_FIR1A_GAIN_BITS : natural := 17;
  constant RFSOC_FIR1A_COEF      : array_signed_t(0 to RFSOC_FIR1A_TAPS-1)(RFSOC_FIR1A_COEF_BITS-1 downto 0) :=
                                 (to_signed(5, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-17, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(44, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-96, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(187, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-335, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(565, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-906, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(1401, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-2112, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(3145, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-4723, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(7415, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-13331, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(41526, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(65536, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(41526, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-13331, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(7415, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-4723, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(3145, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-2112, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(1401, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-906, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(565, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-335, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(187, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-96, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(44, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(-17, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(0, RFSOC_FIR1A_COEF_BITS),
                                  to_signed(5, RFSOC_FIR1A_COEF_BITS)
                                );

  -- PG269 Gen 3/DFE RF-ADC FIR2, 2x decimation half-band
  -- (centre tap 16384, coefficients sum to 2**15)
  constant RFSOC_FIR2_COEF_BITS : natural := 16;
  constant RFSOC_FIR2_TAPS      : natural := 23;
  constant RFSOC_FIR2_GAIN_BITS : natural := 15;
  constant RFSOC_FIR2_COEF      : array_signed_t(0 to RFSOC_FIR2_TAPS-1)(RFSOC_FIR2_COEF_BITS-1 downto 0) :=
                                 (to_signed(-12, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(84, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(-337, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(1008, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(-2693, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(10142, RFSOC_FIR2_COEF_BITS),
                                  to_signed(16384, RFSOC_FIR2_COEF_BITS),
                                  to_signed(10142, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(-2693, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(1008, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(-337, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(84, RFSOC_FIR2_COEF_BITS),
                                  to_signed(0, RFSOC_FIR2_COEF_BITS),
                                  to_signed(-12, RFSOC_FIR2_COEF_BITS)
                                );

  -- PG269 Gen 3/DFE RF-ADC FIR3, 2x decimation half-band
  -- (centre tap 2048, coefficients sum to 2**12)
  constant RFSOC_FIR3_COEF_BITS : natural := 13;
  constant RFSOC_FIR3_TAPS      : natural := 15;
  constant RFSOC_FIR3_GAIN_BITS : natural := 12;
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