-------------------------------------------------------------------------------
-- Author        : Andrew Thornton
-- Creation Date : 2023-Dec-08
-- Standard      : VDHL 2008
-------------------------------------------------------------------------------
-- Rev  Author        Description
-- 1.0  A. Thornton   Testbench Creation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity issue_tb is
end issue_tb;

architecture test_bench of issue_tb is

  -- component and_gate is
  --   port(
  --     clk_i  : in  std_logic;
  --     srst_i : in  std_logic;
  --     a_i    : in  std_logic;
  --     b_i    : in  std_logic;
  --     c_o    : out std_logic
  --   );
  -- end component and_gate;
  
  constant CLOCK_FREQ_MHZ : real := 1.0;
  constant CLOCK_PERIOD   : time := (1.0/CLOCK_FREQ_MHZ) * 1.0 us;
  constant CLOCK_HOLD     : time := CLOCK_PERIOD/10.0;
  
  constant INPUT_DATA_W  : natural := 16;
  constant OUTPUT_DATA_W : natural := 32;

  -- tb clock and reset
  signal tb_clk    : std_logic := '0';
  signal tb_srst   : std_logic := '1';
  
  -- tb inputs
  signal tb_real   : signed(INPUT_DATA_W-1 downto 0) := (others => '0');
  signal tb_imag   : signed(INPUT_DATA_W-1 downto 0) := (others => '0');
  signal tb_vld    : std_logic := '1';

  -- tb outputs
  signal tb_phase     : signed(OUTPUT_DATA_W-1 downto 0):= (others => '0');
  signal tb_phase_vld : std_logic := '0';

begin

  dut : entity work.issue
  generic map(
    ITERATIONS         => 16,
    INPUT_DATA_W       => 16,
    OUTPUT_DATA_W      => 32
  ) port map(
    clk_i   => tb_clk,
    srst_i  => tb_srst,
    real_i  => tb_real,
    imag_i  => tb_imag,
    vld_i   => tb_vld,
    phase_o => tb_phase,
    vld_o   => tb_phase_vld
  );

  tb_clock_proc : process
  begin
    tb_clk <= not(tb_clk);
    wait for CLOCK_PERIOD/2;
  end process tb_clock_proc;
  
  tb_reset_proc : process
  begin
    tb_srst <= '1';
    wait for 9*CLOCK_PERIOD;
    wait until rising_edge(tb_clk);
    tb_srst <= '0';
    wait;
  end process tb_reset_proc;

  tb_input_proc : process(tb_clk)
  begin
    if rising_edge(tb_clk) then
      if tb_srst = '0' then
        tb_real <= tb_real+1;
        tb_imag <= tb_imag+1;
        tb_vld <= '1';
      end if;
    end if;
  end process;

end test_bench;