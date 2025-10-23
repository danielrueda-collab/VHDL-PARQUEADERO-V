Library IEEE;
use IEEE.STD_LOGIC_1164.all;

Entity teclado_matricial is
PORT (
    Reloj : in std_logic;
    Col : in std_logic_vector (3 downto 0);
	 filas : out std_logic_vector (3 downto 0);
    display : out std_logic;
    Segmentos : out std_logic_vector (7 downto 0)
);
End teclado_matricial;

Architecture TecladoMatricial of teclado_matricial is

component LIB_TEC_MATRICIAL_4x4_INTESC_RevA is
    GENERIC(
        FREQ_CLK : INTEGER := 50000000  --FRECUENCIA DE LA TARJETA
    );
    PORT (
        CLK         : IN STD_LOGIC;                           -- RELOJ FPGA
        COLUMNAS    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);          -- PUERTO CONECTADO A LAS COLUMNAS DEL TECLADO
        FILAS       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);         -- PUERTO CONECTADO A LA FILAS DEL TECLADO
        BOTON_PRES  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);         -- PUERTO QUE INDICA LA TECLA QUE SE PRESION
        IND         : OUT STD_LOGIC                             -- BANDERA QUE INDICA CUANDO SE PRESIONÓ UNA TECLA (SÓLO DUR
    );
	 
end component LIB_TEC_MATRICIAL_4x4_INTESC_RevA;

signal boton_pres : std_logic_vector (3 downto 0) := (others => '0');
signal ind : std_logic := '0';
signal segm : std_logic_vector (7 downto 0) := "00000000";

begin

libreria : LIB_TEC_MATRICIAL_4x4_INTESC_RevA Generic map (FREQ_CLK => 50000000)
    port map (Reloj, Col, filas, boton_pres, ind);

Proceso_TECLADO: process (Reloj, ind, boton_pres,segm) begin
    if rising_edge(Reloj) then
        if ind = '1' and boton_pres = "0000" then segm <= "11000000";
        elsif ind = '1' and boton_pres = X"1" then segm <= "11111001";
        elsif ind = '1' and boton_pres = X"2" then segm <= "10100100";
        elsif ind = '1' and boton_pres = X"3" then segm <= "10110000";
        elsif ind = '1' and boton_pres = X"4" then segm <= "10011001";
        elsif ind = '1' and boton_pres = X"5" then segm <= "10010010";
        elsif ind = '1' and boton_pres = X"6" then segm <= "10000010";
        elsif ind = '1' and boton_pres = X"7" then segm <= "11111000";
        elsif ind = '1' and boton_pres = X"8" then segm <= "10000000";
        elsif ind = '1' and boton_pres = X"9" then segm <= "10011000";
        elsif ind = '1' and boton_pres = X"A" then segm <= "10001000";
        elsif ind = '1' and boton_pres = X"B" then segm <= "10000011";
        elsif ind = '1' and boton_pres = X"C" then segm <= "11000110";
        elsif ind = '1' and boton_pres = X"D" then segm <= "10100001";
        elsif ind = '1' and boton_pres = X"E" then segm <= "10000110";
        elsif ind = '1' and boton_pres = X"F" then segm <= "10001110";
        else segm <= segm;
        end if;
    end if;
end process;

display <= '0';
Segmentos <= segm;

end TecladoMatricial;