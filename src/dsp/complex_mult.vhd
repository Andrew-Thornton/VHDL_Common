-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description   : a 4 multiplier complex multiplier
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
  signal vld_z : std_logic := '0';

  signal c_real : signed(2*INPUT_DATA_W downto 0) := (others => '0');
  signal c_imag : signed(2*INPUT_DATA_W downto 0) := (others => '0');
  signal vld_zz : std_logic:= '0';

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

      c_real <= resize(ac, c_real_o'length) - resize(bd, c_real_o'length);
      c_imag <= resize(ad, c_imag_o'length) + resize(bc, c_imag_o'length);
      vld_zz <= vld_z;
    end if;
  end process;

  c_real_o <= c_real;
  c_imag_o <= c_imag;
  vld_o <= vld_zz;

end rtl;
