library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frecuencia_800hz is
    Port ( 
        CLK_SISTEMA : in  STD_LOGIC;  -- Reloj de entrada: 50 MHz
        RESET       : in  STD_LOGIC;
        CLK_LENTO   : out STD_LOGIC   -- Reloj de salida: 800 Hz
    );
end frecuencia_800hz;

architecture Behavioral of frecuencia_800hz is
    -- Frecuencia deseada: F_paso = 800 Hz
    -- Frecuencia del sistema: F_sistema = 50,000,000 Hz
    -- C_MAX = F_sistema / (2 * F_paso)
    -- C_MAX = 50,000,000 / (2 * 800) = 31,250

    constant C_MAX : integer := 31250;
    signal contador : integer range 0 to C_MAX-1 := 0;
    signal clk_temp : std_logic := '0';

begin

    process(CLK_SISTEMA, RESET)
    begin
        if RESET = '1' then
            contador <= 0;
            clk_temp <= '0';
        elsif rising_edge(CLK_SISTEMA) then
            if contador = C_MAX-1 then
                contador <= 0;
                clk_temp <= not clk_temp; -- Invierte la salida cada medio ciclo
            else
                contador <= contador + 1;
            end if;
        end if;
    end process;

    CLK_LENTO <= clk_temp;

end Behavioral;
