-- Archivo: decodificador_bcd_7seg.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity decodificador_bcd_7seg is
    Port ( 
        BCD_IN : in  STD_LOGIC_VECTOR (3 downto 0);
        SEG_OUT : out STD_LOGIC_VECTOR (7 downto 0) -- (a,b,c,d,e,f,g,dp)
    );
end decodificador_bcd_7seg;

architecture Behavioral of decodificador_bcd_7seg is
begin
    process(BCD_IN)
    begin
        case BCD_IN is
            when X"0"   => SEG_OUT <= "11000000"; -- 0
            when X"1"   => SEG_OUT <= "11111001"; -- 1
            when X"2"   => SEG_OUT <= "10100100"; -- 2
            when X"3"   => SEG_OUT <= "10110000"; -- 3
            when X"4"   => SEG_OUT <= "10011001"; -- 4
            when X"5"   => SEG_OUT <= "10010010"; -- 5
            when X"6"   => SEG_OUT <= "10000010"; -- 6
            when X"7"   => SEG_OUT <= "11111000"; -- 7
            when X"8"   => SEG_OUT <= "10000000"; -- 8
            when X"9"   => SEG_OUT <= "10010000"; -- 9 (Ajustado desde tu código original)
            when others => SEG_OUT <= "11111111"; -- Apagado (blank)
        end case;
    end process;
end Behavioral;