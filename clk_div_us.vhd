library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_div_us is
  generic (
    F_CLK_HZ  : positive := 50000000;  -- Frecuencia de reloj de la FPGA
    F_TICK_HZ : positive := 1000000   -- Frecuencia del tick deseado (1 MHz -> 1 us)
  );
  port (
    clk   : in  std_logic;
    rst_n : in  std_logic;           -- reset activo en '0'
    tick  : out std_logic            -- pulso de 1 ciclo cada 1 us
  );
end entity;

architecture rtl of clk_div_us is
  constant DIVISOR : positive := F_CLK_HZ / F_TICK_HZ;
  signal cnt      : unsigned(31 downto 0) := (others => '0');
  signal tick_i   : std_logic := '0';
begin
  tick <= tick_i;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        cnt    <= (others => '0');
        tick_i <= '0';
      else
        if cnt = to_unsigned(DIVISOR - 1, cnt'length) then
          cnt    <= (others => '0');
          tick_i <= '1';
        else
          cnt    <= cnt + 1;
          tick_i <= '0';
        end if;
      end if;
    end if;
  end process;
end architecture;