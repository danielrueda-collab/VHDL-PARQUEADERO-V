-- Archivo: bin_to_bcd_4digit.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bin_to_bcd_4digit is
    Port ( 
        BIN_IN  : in  integer range 0 to 9999;
        BCD_OUT : out std_logic_vector(15 downto 0)  -- 4 dígitos BCD
    );
end bin_to_bcd_4digit;

architecture Behavioral of bin_to_bcd_4digit is
begin
    process(BIN_IN)
        variable v_bin                 : integer;
        variable v_mil, v_cen, v_dec, v_uni : integer;
    begin
        v_bin := BIN_IN;

        v_mil := v_bin / 1000;
        v_bin := v_bin mod 1000;

        v_cen := v_bin / 100;
        v_bin := v_bin mod 100;

        v_dec := v_bin / 10;
        v_uni := v_bin mod 10;

        BCD_OUT(15 downto 12) <= std_logic_vector(to_unsigned(v_mil, 4));
        BCD_OUT(11 downto 8)  <= std_logic_vector(to_unsigned(v_cen, 4));
        BCD_OUT(7 downto 4)   <= std_logic_vector(to_unsigned(v_dec, 4));
        BCD_OUT(3 downto 0)   <= std_logic_vector(to_unsigned(v_uni, 4));
    end process;
end Behavioral;