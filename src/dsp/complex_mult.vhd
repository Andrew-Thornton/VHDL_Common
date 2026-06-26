-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description   : a 4 multiplier complex multiplier
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vhdl_common;
use vhdl_common.math_utils_pkg.ceil_log2;

entity complex_mult is
  generic(
    INPUT_DATA_W      : positive := 16
  );
  port(
    clk_i    : in  std_logic;
    srst_i   : in  std_logic;
    a_real_i : in  signed(INPUT_DATA_W-1 downto 0);
    a_imag_i : in  signed(INPUT_DATA_W-1 downto 0);
    b_real_i : in  signed(INPUT_DATA_W-1 downto 0);
    b_imag_i : in  signed(INPUT_DATA_W-1 downto 0);
    vld_i    : in  std_logic;
    c_real_o : out signed(2*INPUT_DATA_W downto 0);
    c_imag_o : out signed(2*INPUT_DATA_W downto 0);
    vld_o    : out std_logic
  );
end complex_mult;

architecture rtl of complex_mult is

  signal ac : signed((2*INPUT_DATA_W)-1 downto 0) := (others => '0');
  signal bd : signed((2*INPUT_DATA_W)-1 downto 0) := (others => '0');
  signal ad : signed((2*INPUT_DATA_W)-1 downto 0) := (others => '0');
  signal bc : signed((2*INPUT_DATA_W)-1 downto 0) := (others => '0');  

  signal vld_z : std_logic;
begin

  --the following computes
  --  (a + bi) * (c + di)
  -- =(ac - bd) + (ad + bc)i
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      ac <= a_real_i * b_real_i;
      bd <= a_imag_i * b_imag_i;
      ad <= a_real_i * b_imag_i;
      bc <= a_imag_i * b_real_i;
      vld_z <= vld_i;

      c_real_o <= resize(ac, 2*INPUT_DATA_W) - resize(bd, 2*INPUT_DATA_W);
      c_imag_o <= resize(ad, 2*INPUT_DATA_W) + resize(bc, 2*INPUT_DATA_W);
      vld_o <= vld_z;
    end if;
  end process;

end rtl;
