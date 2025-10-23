library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity secuenciador_de_pasos_rapido is
    Port ( 
        CLK_PASO   : in  STD_LOGIC;  -- Pulso proveniente del divisor
        RESET      : in  STD_LOGIC;
        DIRECTION  : in  STD_LOGIC;  -- '1' horario, '0' antihorario
        PINS_OUT   : out STD_LOGIC_VECTOR (3 downto 0)  -- IN1, IN2, IN3, IN4
    );
end secuenciador_de_pasos_rapido;

architecture Behavioral of secuenciador_de_pasos_rapido is

    type State_Type is (S0, S1, S2, S3, S4, S5, S6, S7);
    signal state : State_Type := S0;

begin

    process(CLK_PASO, RESET)
    begin
        if RESET = '1' then
            state <= S0;
        elsif rising_edge(CLK_PASO) then
            case state is
                when S0 => if DIRECTION='1' then state<=S1; else state<=S7; end if;
                when S1 => if DIRECTION='1' then state<=S2; else state<=S0; end if;
                when S2 => if DIRECTION='1' then state<=S3; else state<=S1; end if;
                when S3 => if DIRECTION='1' then state<=S4; else state<=S2; end if;
                when S4 => if DIRECTION='1' then state<=S5; else state<=S3; end if;
                when S5 => if DIRECTION='1' then state<=S6; else state<=S4; end if;
                when S6 => if DIRECTION='1' then state<=S7; else state<=S5; end if;
                when S7 => if DIRECTION='1' then state<=S0; else state<=S6; end if;
            end case;
        end if;
    end process;

    -- Salidas: patrón medio paso
    with state select
        PINS_OUT <=
            "1000" when S0,  -- 1
            "1100" when S1,  -- 1+2
            "0100" when S2,  -- 2
            "0110" when S3,  -- 2+3
            "0010" when S4,  -- 3
            "0011" when S5,  -- 3+4
            "0001" when S6,  -- 4
            "1001" when S7,  -- 4+1
            "0000" when others;

end Behavioral;
