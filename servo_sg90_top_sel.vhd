-- Archivo: servo_sg90_top_sel.vhd (MODIFICADO)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity servo_sg90_top_sel is
  generic (
    F_CLK_HZ          : positive := 50000000;
    CENTER_US         : positive := 1500;  -- posición neutra (detención)

    -- Fase COARSE: rápido para la mayor parte del giro
    COARSE_DELTA_US : positive := 400;   -- 1500±400 (velocidad)
    T_COARSE_MS     : positive := 430;   -- AUMENTADO (antes 311)

    -- Fase FINE: lento para el ajuste final
    FINE_DELTA_US   : positive := 140;   -- 1500±140 (más suave)
    T_FINE_MS       : positive := 70;    -- AUMENTADO (antes 49)

    -- Tiempo de asentamiento entre fases y al final
    SETTLE_MS       : positive := 30
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;           -- reset activo en '0'
    sel       : in  std_logic;           -- flanco = giro en sentido de 'sel'
    servo_pwm : out std_logic
  );
end entity;

architecture structural of servo_sg90_top_sel is
  --------------------------------------------------------------------
  -- Componentes (Estos deben existir en tu proyecto)
  --------------------------------------------------------------------
  component clk_div_us
    generic (
      F_CLK_HZ  : positive := 50000000;
      F_TICK_HZ : positive := 1000000
    );
    port (
      clk   : in std_logic;
      rst_n : in std_logic;
      tick  : out std_logic
    );
  end component;

  component pwm_sg90
    generic (
      FRAME_US     : positive := 20000;
      PULSE_MIN_US : positive := 1000;
      PULSE_MAX_US : positive := 2000
    );
    port (
      clk      : in std_logic;
      rst_n    : in std_logic;
      tick_us  : in std_logic;
      width_us : in integer;
      pwm_out  : out std_logic
    );
  end component;

  --------------------------------------------------------------------
  -- Señales internas
  --------------------------------------------------------------------
  type state_t is (IDLE, START_COARSE, RUN_COARSE, SETTLE1, START_FINE, RUN_FINE, STOP);
  signal st           : state_t := IDLE;

  signal tick_1us     : std_logic;
  signal width_us_s   : integer := CENTER_US;

  -- sincronización y flanco de 'sel'
  signal sel_sync0, sel_sync1, sel_prev : std_logic := '0';

  -- dirección (1 = +, 0 = -)
  signal dir_plus     : std_logic := '0';

  -- contador microsegundos
  signal us_cnt       : unsigned(31 downto 0) := (others => '0');

  -- tiempos en us
  constant COARSE_US  : natural := T_COARSE_MS * 1000;
  constant FINE_US    : natural := T_FINE_MS   * 1000;
  constant SETTLE_US  : natural := SETTLE_MS   * 1000;

begin
  --------------------------------------------------------------------
  -- Divisor 1us
  --------------------------------------------------------------------
  U_DIV: clk_div_us
    generic map (
      F_CLK_HZ  => F_CLK_HZ,
      F_TICK_HZ => 1000000
    )
    port map (
      clk   => clk,
      rst_n => rst_n,
      tick  => tick_1us
    );

  --------------------------------------------------------------------
  -- PWM 50 Hz para servo
  --------------------------------------------------------------------
  U_PWM: pwm_sg90
    generic map (
      FRAME_US     => 20000,
      PULSE_MIN_US => 1000,  -- Rango clamp (1000 a 2000)
      PULSE_MAX_US => 2000
    )
    port map (
      clk       => clk,
      rst_n     => rst_n,
      tick_us   => tick_1us,
      width_us  => width_us_s,
      pwm_out   => servo_pwm
    );

  --------------------------------------------------------------------
  -- Sincronización y detección de flanco de 'sel'
  --------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        sel_sync0 <= '0';
        sel_sync1 <= '0';
        sel_prev  <= '0';
      else
        sel_sync0 <= sel;
        sel_sync1 <= sel_sync0;
        sel_prev  <= sel_sync1;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- FSM
  --------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        st         <= IDLE;
        width_us_s <= CENTER_US;
        dir_plus   <= '0';
        us_cnt     <= (others => '0');
      else
        case st is
          when IDLE =>
            width_us_s <= CENTER_US; -- Detenido
            us_cnt     <= (others => '0');
            if sel_sync1 /= sel_prev then -- Detecta flanco
              dir_plus <= sel_sync1;  -- Guarda la dirección
              st       <= START_COARSE;
            end if;

          when START_COARSE =>
            if dir_plus = '1' then
              width_us_s <= CENTER_US + COARSE_DELTA_US; -- Gira +
            else
              width_us_s <= CENTER_US - COARSE_DELTA_US; -- Gira -
            end if;
            us_cnt <= (others => '0');
            st     <= RUN_COARSE;

          when RUN_COARSE =>
            if tick_1us = '1' then
              if us_cnt = to_unsigned(COARSE_US - 1, us_cnt'length) then
                width_us_s <= CENTER_US; -- detener
                us_cnt     <= (others => '0');
                st         <= SETTLE1;
              else
                us_cnt <= us_cnt + 1;
              end if;
            end if;

          when SETTLE1 =>
            if tick_1us = '1' then
              if us_cnt = to_unsigned(SETTLE_US - 1, us_cnt'length) then
                if dir_plus = '1' then
                  width_us_s <= CENTER_US + FINE_DELTA_US;
                else
                  width_us_s <= CENTER_US - FINE_DELTA_US;
                end if;
                us_cnt <= (others => '0');
                st     <= START_FINE;
              else
                us_cnt <= us_cnt + 1;
              end if;
            end if;

          when START_FINE =>
            st <= RUN_FINE;

          when RUN_FINE =>
            if tick_1us = '1' then
              if us_cnt = to_unsigned(FINE_US - 1, us_cnt'length) then
                width_us_s <= CENTER_US; -- detener servo
                st         <= STOP;
              else
                us_cnt <= us_cnt + 1;
              end if;
            end if;

          when STOP =>
            width_us_s <= CENTER_US; -- permanece detenido
            if sel_sync1 /= sel_prev then -- Listo para otro flanco
              dir_plus <= sel_sync1;
              st       <= START_COARSE;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;