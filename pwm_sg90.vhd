-- pwm_sg90.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_sg90 is
  generic (
    FRAME_US     : positive := 20000;  -- 20 ms (50 Hz)
    PULSE_MIN_US : positive := 1000;   -- ~-90°
    PULSE_MAX_US : positive := 2000    -- ~+90°
  );
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    tick_us  : in  std_logic;          -- enable de 1 us
    width_us : in  integer;            -- ancho en microsegundos
    pwm_out  : out std_logic
  );
end entity;

architecture rtl of pwm_sg90 is
  signal ctr_us    : integer range 0 to FRAME_US-1 := 0;
  signal pwm_reg   : std_logic := '0';
  signal width_eff : integer := PULSE_MIN_US; -- ancho clamped a [MIN,MAX]
begin
  pwm_out <= pwm_reg;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        ctr_us   <= 0;
        pwm_reg  <= '0';
        width_eff <= PULSE_MIN_US;
      else
        if tick_us = '1' then
          -- Limitar ancho a [PULSE_MIN_US, PULSE_MAX_US]
          if width_us < PULSE_MIN_US then
            width_eff <= PULSE_MIN_US;
          elsif width_us > PULSE_MAX_US then
            width_eff <= PULSE_MAX_US;
          else
            width_eff <= width_us;
          end if;

          -- Contador de frame (20 ms)
          if ctr_us = FRAME_US - 1 then
            ctr_us <= 0;
          else
            ctr_us <= ctr_us + 1;
          end if;

          -- Generación del PWM
          if ctr_us < width_eff then
            pwm_reg <= '1';
          else
            pwm_reg <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;