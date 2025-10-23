-- Archivo: display_multiplexer.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity display_multiplexer is
    Port ( 
        CLK_50MHz : in  STD_LOGIC;
        RESET     : in  STD_LOGIC;
        VALUE_IN_BCD : in  STD_LOGIC_VECTOR (15 downto 0); -- 4 digitos
        
        DISPLAY_ANODES : out STD_LOGIC_VECTOR (3 downto 0);
        DISPLAY_SEGS   : out STD_LOGIC_VECTOR (7 downto 0)
    );
end display_multiplexer;

architecture Behavioral of display_multiplexer is

    -- Componente del decodificador
    component decodificador_bcd_7seg
        Port ( 
            BCD_IN : in  STD_LOGIC_VECTOR (3 downto 0);
            SEG_OUT : out STD_LOGIC_VECTOR (7 downto 0)
        );
    end component;

    -- Divisor de frecuencia para el MUX (aprox 1kHz)
    constant MUX_CLK_MAX : integer := 25000; -- 50MHz / (2 * 1kHz) = 25000
    signal mux_clk_counter : integer range 0 to MUX_CLK_MAX-1 := 0;
    signal mux_clk         : std_logic := '0';
    
    -- Contador para seleccionar el dígito
    signal mux_digit_sel : unsigned(1 downto 0) := "00";
    
    -- Señales internas
    signal current_digit_bcd : std_logic_vector(3 downto 0);
    signal current_segs    : std_logic_vector(7 downto 0);
    signal current_anodes  : std_logic_vector(3 downto 0);

begin

    -- Proceso 1: Generador de reloj para el MUX (1kHz)
    process(CLK_50MHz, RESET)
    begin
        if RESET = '1' then
            mux_clk_counter <= 0;
            mux_clk <= '0';
        elsif rising_edge(CLK_50MHz) then
            if mux_clk_counter = MUX_CLK_MAX-1 then
                mux_clk_counter <= 0;
                mux_clk <= not mux_clk;
            else
                mux_clk_counter <= mux_clk_counter + 1;
            end if;
        end if;
    end process;
    
    -- Proceso 2: Lógica de multiplexación
    process(mux_clk, RESET)
    begin
        if RESET = '1' then
            mux_digit_sel <= "00";
        elsif rising_edge(mux_clk) then
            -- Rotar el selector de dígito (00 -> 01 -> 10 -> 11 -> 00)
            mux_digit_sel <= mux_digit_sel + 1;
        end if;
    end process;

    -- Proceso 3: Selección de dígito y ánodo
    process(mux_digit_sel, VALUE_IN_BCD)
    begin
        case mux_digit_sel is
            -- Digito 0 (Unidades)
            when "00" => 
                current_digit_bcd <= VALUE_IN_BCD(3 downto 0);
                current_anodes    <= "1110"; -- Activa Anodo 0
            -- Digito 1 (Decenas)
            when "01" => 
                current_digit_bcd <= VALUE_IN_BCD(7 downto 4);
                current_anodes    <= "1101"; -- Activa Anodo 1
            -- Digito 2 (Centenas)
            when "10" => 
                current_digit_bcd <= VALUE_IN_BCD(11 downto 8);
                current_anodes    <= "1011"; -- Activa Anodo 2
            -- Digito 3 (Millares)
            when "11" => 
                current_digit_bcd <= VALUE_IN_BCD(15 downto 12);
                current_anodes    <= "0111"; -- Activa Anodo 3
            when others =>
                current_digit_bcd <= "1111"; -- Blank
                current_anodes    <= "1111"; -- Todos apagados
        end case;
    end process;

    -- Instancia del Decodificador
    U_BCD_DECODER : decodificador_bcd_7seg
        port map (
            BCD_IN  => current_digit_bcd,
            SEG_OUT => current_segs
        );

    -- Asignación final
    DISPLAY_ANODES <= current_anodes;
    DISPLAY_SEGS   <= current_segs;

end Behavioral;