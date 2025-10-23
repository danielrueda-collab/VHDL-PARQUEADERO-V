library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Entidad Top Level
entity motor_a_pasos_4 is
    Port (
        -- Entradas del sistema (Conexión a la FPGA)
        CLK_50MHz   : in  STD_LOGIC;  -- Reloj del oscilador (50 MHz)
        RESET       : in  STD_LOGIC;  -- Señal de reinicio
        DIRECTION   : in  STD_LOGIC;  -- Control de dirección ('1' CW, '0' CCW)

        -- Salidas al Driver ULN2003A (Conexión a los pines IN1-IN4)
        MOTOR_PINS  : out STD_LOGIC_VECTOR (3 downto 0) 
    );
end motor_a_pasos_4;

architecture Structural of motor_a_pasos_4 is
    
    -- Declaración de la señal que conecta los dos bloques
    signal clk_step_signal : STD_LOGIC;

    ------------------------------------------------------------------
    -- Declaración de Componentes (Definiciones de los módulos que usas)
    ------------------------------------------------------------------
    
    -- Componente 1: Divisor de Frecuencia a 200 Hz
    component frecuencia_800hz
    Port ( 
        CLK_SISTEMA : in  STD_LOGIC; 
        RESET       : in  STD_LOGIC; 
        CLK_LENTO   : out STD_LOGIC 
    );
    end component;

    -- Componente 2: Secuenciador de Pasos 28BYJ-48 (Unipolar, 4/8 pasos)
    component secuenciador_de_pasos_rapido
    Port ( 
        CLK_PASO    : in  STD_LOGIC; 
        RESET       : in  STD_LOGIC; 
        DIRECTION   : in  STD_LOGIC; 
        PINS_OUT    : out STD_LOGIC_VECTOR (3 downto 0) 
    );
    end component;

begin
    
    -- 1. Instanciación y Conexión del Divisor de Frecuencia
    U1_DIVISOR : frecuencia_800hz
    port map (
        CLK_SISTEMA => CLK_50MHz,             -- Entrada de 50 MHz
        RESET       => RESET,
        CLK_LENTO   => clk_step_signal        -- Salida: Pulso de 200 Hz
    );

    -- 2. Instanciación y Conexión del Secuenciador de Pasos
    U2_SEQUENCER : secuenciador_de_pasos_rapido
    port map (
        CLK_PASO    => clk_step_signal,       -- Entrada: Pulso de 200 Hz del divisor
        RESET       => RESET,
        DIRECTION   => DIRECTION,             -- Entrada: Control de dirección
        PINS_OUT    => MOTOR_PINS             -- Salidas finales al driver
    );

end Structural;