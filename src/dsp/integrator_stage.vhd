-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Standard      : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-- Integrator stage designed as a part of a CIC Filter
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity integrator_stage is
  generic(
    DIFFERENTIAL_DELAY : positive := 1;
    INPUT_DATA_W       : positive := 16
  );
  port(
    clk_i   : in  std_logic;
    srst_i  : in  std_logic;
    a_i     : in  signed(INPUT_DATA_W-1 downto 0);
    a_vld_i : in  std_logic := '1';
    b_o     : out signed(INPUT_DATA_W downto 0);
    b_vld_o : out std_logic
  );
end integrator_stage;

architecture rtl of integrator_stage is

  type signed_array_t is array (natural range <>) of signed;

  -- res_delay holds DIFFERENTIAL_DELAY elements: indices 1 to DIFFERENTIAL_DELAY.
  -- When DIFFERENTIAL_DELAY=1 this is a single-element array (1 to 1), which is
  -- the accumulator register.  The previous "1 to DIFFERENTIAL_DELAY-1" gave a
  -- null range (1 to 0) for DIFFERENTIAL_DELAY=1, causing the index error.
  signal res_delay : signed_array_t(1 to DIFFERENTIAL_DELAY)(INPUT_DATA_W downto 0)
                     := (others => (others => '0'));
  signal vld_delay : std_logic := '0';

begin

  integrator_p : process(clk_i)
    variable a_i_se            : signed(INPUT_DATA_W downto 0);
    variable res_last_delay_se : signed(INPUT_DATA_W downto 0);
  begin
    if rising_edge(clk_i) then
      -- delay line default (hold)
      res_delay <= res_delay;
      vld_delay <= a_vld_i;

      if a_vld_i = '1' then
        a_i_se            := resize(a_i, INPUT_DATA_W+1);
        res_last_delay_se := res_delay(DIFFERENTIAL_DELAY);       -- oldest sample
        res_delay(1)      <= a_i_se + res_last_delay_se;          -- accumulate into index 1
        if DIFFERENTIAL_DELAY > 1 then
          res_delay(2 to DIFFERENTIAL_DELAY) <= res_delay(1 to DIFFERENTIAL_DELAY-1);
        end if;
      end if;

      if srst_i = '1' then
        vld_delay <= '0';
        res_delay <= (others => (others => '0'));
      end if;

    end if;
  end process;

  b_o     <= res_delay(1);   -- most-recent accumulator value
  b_vld_o <= vld_delay;

end rtl;
