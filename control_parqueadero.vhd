-- Archivo: control_parqueadero.vhd (CORREGIDO)
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_parqueadero is
    Port ( 
        CLK_50MHz   : in  STD_LOGIC;
        RESET       : in  STD_LOGIC;
        CLK_10HZ_IN : in  STD_LOGIC;
        CLK_1HZ_IN  : in  STD_LOGIC; -- Reloj de 1Hz para cobro
        
        KEY_PRESSED : in  STD_LOGIC;
        KEY_VALUE   : in  STD_LOGIC_VECTOR (3 downto 0);
        
        MOTOR_ENABLE : out STD_LOGIC;
        DOOR_OPEN    : out STD_LOGIC;
        
        LED_FULL_BLINK : out STD_LOGIC; -- LED "Lleno"
        DISPLAY_VALUE_OUT : out INTEGER range 0 to 9999 -- Valor para el display
    );
end control_parqueadero;

architecture Behavioral of control_parqueadero is

    -- Estados
    type t_state is (
        S_IDLE,             
        S_MOVE_TO_GARAGE,
        S_BILLING,          
        S_GIVE_CHANGE,      
        S_PAUSE,            
        S_RETURN_TO_HOME    
    );
    signal state_reg, state_next : t_state := S_IDLE;
    
    type t_op_mode is ( OP_ASSIGN, OP_RETRIEVE );
    signal operation_mode_reg, operation_mode_next : t_op_mode := OP_ASSIGN;
    
    -- Temporizador FSM (10Hz)
    signal timer_reg, timer_next : integer := 0;
    signal target_count_reg, target_count_next : integer := 0;
    
    -- Posición actual y destino
    signal current_garage_reg, current_garage_next : integer range 1 to 8 := 1;
    signal target_garage_reg, target_garage_next   : integer range 1 to 8 := 1;
    
    -- Estado de garajes (0=Libre, 1=Ocupado)
    signal garage_status_reg, garage_status_next : std_logic_vector(7 downto 0) := (others => '0');
    
    -- Tiempo por garaje (en segundos)
    type t_garage_time_array is array (0 to 7) of integer range 0 to 1000000;
    signal garage_time_reg, garage_time_next : t_garage_time_array := (others => 0);

    -- Cobro
    signal cost_reg,    cost_next    : integer range 0 to 9999 := 0;
    signal payment_reg, payment_next : integer range 0 to 9999 := 0;

    -- Constantes
    constant TICKS_PER_SPACE   : integer := 73;   -- 7.3 s @10Hz
    constant TICKS_PAUSE       : integer := 150;  -- 15 s
    constant TICKS_SHOW_CHANGE : integer := 50;   -- 5 s
    
    -- Teclas
    constant KEY_ASSIGN   : std_logic_vector(3 downto 0) := X"A";
    constant KEY_PAY_1000 : std_logic_vector(3 downto 0) := X"B";
    constant KEY_PAY_500  : std_logic_vector(3 downto 0) := X"C";

    -- Ticks de reloj
    signal clk_10hz_prev   : std_logic := '0';
    signal tick_10hz_event : std_logic := '0';

    signal clk_1hz_prev    : std_logic := '0';
    signal tick_1hz_event  : std_logic := '0';
    
    -- LED "Lleno"
    signal parking_full     : std_logic := '0';
    signal led_full_counter : integer range 0 to 6 := 0; -- 0.7 s @10Hz
    signal led_full_state   : std_logic := '0';
    
    -- Display
    signal display_value_reg,  display_value_next  : integer range 0 to 9999 := 0;
    signal display_timer_reg,  display_timer_next  : integer range 0 to 50 := 0; -- 5 s @10Hz

    -- Petición para limpiar tiempo de un slot (atendida por el proceso de tiempos)
    signal clear_time_req_reg,  clear_time_req_next  : std_logic := '0';
    signal clear_time_idx_reg,  clear_time_idx_next  : integer range 0 to 7 := 0;

begin
    -- Señal de "parqueadero lleno"
    parking_full <= '1' when garage_status_reg = "11111111" else '0';

    ---------------------------------------------------------------------------
    -- Proceso 1: Registros síncronos (50MHz)
    ---------------------------------------------------------------------------
    process(CLK_50MHz, RESET)
    begin
        if RESET = '1' then
            state_reg          <= S_IDLE;
            timer_reg          <= 0;
            target_count_reg   <= 0;
            current_garage_reg <= 1;
            target_garage_reg  <= 1;
            clk_10hz_prev      <= '0';
            clk_1hz_prev       <= '0';
            garage_status_reg  <= (others => '0');
            operation_mode_reg <= OP_ASSIGN;
            garage_time_reg    <= (others => 0);
            cost_reg           <= 0;
            payment_reg        <= 0;
            display_value_reg  <= 0;
            display_timer_reg  <= 0;
            led_full_counter   <= 0;
            led_full_state     <= '0';
            clear_time_req_reg <= '0';
            clear_time_idx_reg <= 0;
        elsif rising_edge(CLK_50MHz) then
            state_reg          <= state_next;
            timer_reg          <= timer_next;
            target_count_reg   <= target_count_next;
            current_garage_reg <= current_garage_next;
            target_garage_reg  <= target_garage_next;
            clk_10hz_prev      <= CLK_10HZ_IN;
            clk_1hz_prev       <= CLK_1HZ_IN;
            garage_status_reg  <= garage_status_next;
            operation_mode_reg <= operation_mode_next;
            garage_time_reg    <= garage_time_next;
            cost_reg           <= cost_next;
            payment_reg        <= payment_next;
            display_value_reg  <= display_value_next;
            display_timer_reg  <= display_timer_next;
            clear_time_req_reg <= clear_time_req_next;
            clear_time_idx_reg <= clear_time_idx_next;

            -- LED "lleno"
            if tick_10hz_event = '1' and parking_full = '1' then
                if led_full_counter = 6 then
                    led_full_counter <= 0;
                    led_full_state   <= not led_full_state;
                else
                    led_full_counter <= led_full_counter + 1;
                end if;
            elsif parking_full = '0' then
                led_full_state   <= '0';
                led_full_counter <= 0;
            end if;
        end if;
    end process;

    -- Detectores de flanco
    tick_10hz_event <= '1' when (CLK_10HZ_IN = '1' and clk_10hz_prev = '0') else '0';
    tick_1hz_event  <= '1' when (CLK_1HZ_IN  = '1' and clk_1hz_prev  = '0') else '0';

    ---------------------------------------------------------------------------
    -- Proceso 2: Gestión de tiempos por garaje (ÚNICO driver de garage_time_next)
    --   - Corre a 50MHz y usa tick_1hz_event para contar cada 1 s
    --   - Atiende peticiones de borrado desde la FSM
    ---------------------------------------------------------------------------
    process(CLK_50MHz, RESET)
    begin
        if RESET = '1' then
            garage_time_next <= (others => 0);
        elsif rising_edge(CLK_50MHz) then
            -- Mantener por defecto
            garage_time_next <= garage_time_reg;

            -- Incremento cada 1 segundo para puestos ocupados
            if tick_1hz_event = '1' then
                for i in 0 to 7 loop
                    if garage_status_reg(i) = '1' then
                        garage_time_next(i) <= garage_time_reg(i) + 1;
                    end if;
                end loop;
            end if;

            -- Borrado solicitado por FSM (tiene prioridad)
            if clear_time_req_reg = '1' then
                garage_time_next(clear_time_idx_reg) <= 0;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Proceso 3: FSM y temporizadores (Combinacional)
    ---------------------------------------------------------------------------
    process(state_reg, timer_reg, target_count_reg, current_garage_reg, 
            target_garage_reg, KEY_PRESSED, KEY_VALUE, tick_10hz_event, 
            garage_status_reg, operation_mode_reg, garage_time_reg, 
            cost_reg, payment_reg, display_timer_reg)
        variable v_key_num        : integer range 0 to 15;
        variable v_found_garage   : integer range 0 to 8;
        variable v_spaces_to_move : integer range 0 to 8;
        variable v_cost           : integer;
    begin
        -- Valores por defecto
        state_next          <= state_reg;
        timer_next          <= timer_reg;
        target_count_next   <= target_count_reg;
        current_garage_next <= current_garage_reg;
        target_garage_next  <= target_garage_reg;
        garage_status_next  <= garage_status_reg;
        operation_mode_next <= operation_mode_reg;
        cost_next           <= cost_reg;
        payment_next        <= payment_reg;
        display_value_next  <= display_value_reg;
        display_timer_next  <= display_timer_reg;

        -- Petición de limpieza: por defecto, desactivada
        clear_time_req_next <= '0';
        clear_time_idx_next <= clear_time_idx_reg;

        MOTOR_ENABLE        <= '0'; 
        DOOR_OPEN           <= '0';

        -- Temporizador de 5s para apagar display
        if tick_10hz_event = '1' and display_timer_reg > 0 then
            display_timer_next <= display_timer_reg - 1;
        end if;

        case state_reg is
            when S_IDLE =>
                MOTOR_ENABLE <= '0';
                DOOR_OPEN    <= '0';
                timer_next   <= 0;
                
                if KEY_PRESSED = '1' then
                    v_key_num := to_integer(unsigned(KEY_VALUE));
                    display_value_next <= v_key_num; -- Muestra la tecla
                    display_timer_next <= 50;        -- 5 s
                    
                    if KEY_VALUE = KEY_ASSIGN then
                        v_found_garage := 0;
                        for i in 0 to 7 loop
                            if garage_status_reg(i) = '0' and v_found_garage = 0 then
                                v_found_garage := i + 1;
                            end if;
                        end loop;
                        
                        if v_found_garage > 0 then
                            garage_status_next(v_found_garage - 1) <= '1';
                            operation_mode_next <= OP_ASSIGN;
                            target_garage_next  <= v_found_garage;
                            
                            if v_found_garage = current_garage_reg then
                                target_count_next <= TICKS_PAUSE;
                                timer_next        <= 0;
                                state_next        <= S_PAUSE;
                            else
                                v_spaces_to_move    := (v_found_garage - current_garage_reg + 8) mod 8;
                                target_count_next   <= v_spaces_to_move * TICKS_PER_SPACE;
                                timer_next          <= 0;
                                state_next          <= S_MOVE_TO_GARAGE;
                            end if;
                        end if;
                    
                    elsif (v_key_num >= 1) and (v_key_num <= 8) then
                        if garage_status_reg(v_key_num - 1) = '1' then
                            operation_mode_next <= OP_RETRIEVE;
                            target_garage_next  <= v_key_num;
                            
                            if v_key_num = current_garage_reg then
                                -- En base, ir directo a cobro
                                v_cost := (garage_time_reg(v_key_num - 1) / 60) * 500;
                                cost_next    <= v_cost;
                                payment_next <= 0;
                                display_value_next <= v_cost;
                                display_timer_next <= 50;
                                state_next   <= S_BILLING;
                            else
                                v_spaces_to_move    := (v_key_num - current_garage_reg + 8) mod 8;
                                target_count_next   <= v_spaces_to_move * TICKS_PER_SPACE;
                                timer_next          <= 0;
                                state_next          <= S_MOVE_TO_GARAGE;
                            end if;
                        end if;
                    end if;
                end if;

            when S_MOVE_TO_GARAGE =>
                MOTOR_ENABLE <= '1';
                DOOR_OPEN    <= '0'; 
                
                if tick_10hz_event = '1' then
                    if timer_reg < (target_count_reg - 1) then
                        timer_next <= timer_reg + 1;
                    else
                        -- Movimiento terminado
                        current_garage_next <= target_garage_reg;
                        timer_next        <= 0;
                        
                        if operation_mode_reg = OP_ASSIGN then
                            target_count_next <= TICKS_PAUSE;
                            state_next        <= S_PAUSE;
                        else
                            -- Recuperación: ir a cobro
                            v_cost := (garage_time_reg(target_garage_reg - 1) / 60) * 500;
                            cost_next    <= v_cost;
                            payment_next <= 0;
                            display_value_next <= v_cost;
                            display_timer_next <= 50;
                            state_next   <= S_BILLING;
                        end if;
                    end if;
                end if;

            when S_BILLING =>
                MOTOR_ENABLE <= '0';
                DOOR_OPEN    <= '0';
                
                -- Mostrar saldo pendiente
                if (cost_reg > payment_reg) then
                    display_value_next <= cost_reg - payment_reg;
                else
                    display_value_next <= 0;
                end if;
                display_timer_next <= 50;
                
                -- Pago
                if KEY_PRESSED = '1' then
                    if KEY_VALUE = KEY_PAY_1000 then
                        payment_next <= payment_reg + 1000;
                    elsif KEY_VALUE = KEY_PAY_500 then
                        payment_next <= payment_reg + 500;
                    end if;
                end if;
                
                -- Suficiente pago
                if (payment_reg >= cost_reg) then
                    target_count_next <= TICKS_SHOW_CHANGE;
                    timer_next        <= 0;
                    state_next        <= S_GIVE_CHANGE;
                end if;

            when S_GIVE_CHANGE =>
                MOTOR_ENABLE <= '0';
                DOOR_OPEN    <= '0';
                
                -- Devuelta
                display_value_next <= payment_reg - cost_reg;
                display_timer_next <= 50;
                
                if tick_10hz_event = '1' then
                    if timer_reg < (target_count_reg - 1) then
                        timer_next <= timer_reg + 1;
                    else
                        -- Fin de devuelta
                        payment_next      <= 0;
                        cost_next         <= 0;
                        target_count_next <= TICKS_PAUSE; -- 15 s para abrir
                        timer_next        <= 0;
                        state_next        <= S_PAUSE;
                    end if;
                end if;

            when S_PAUSE =>
                MOTOR_ENABLE <= '0';
                DOOR_OPEN    <= '1'; -- Abrir puerta
                display_timer_next <= 0; -- Apaga display
                
                if tick_10hz_event = '1' then
                    if timer_reg < (target_count_reg - 1) then
                        timer_next <= timer_reg + 1;
                    else
                        if operation_mode_reg = OP_RETRIEVE then
                            -- Liberar garaje y solicitar limpieza de tiempo
                            garage_status_next(target_garage_reg - 1) <= '0';
                            clear_time_req_next <= '1';
                            clear_time_idx_next <= target_garage_reg - 1;
                        end if;
                        
                        -- Volver a la base (1)
                        v_spaces_to_move    := (1 - current_garage_reg + 8) mod 8;
                        target_count_next   <= v_spaces_to_move * TICKS_PER_SPACE;
                        target_garage_next  <= 1;
                        timer_next          <= 0;
                        state_next          <= S_RETURN_TO_HOME;
                    end if;
                end if;
                
            when S_RETURN_TO_HOME =>
                MOTOR_ENABLE <= '1';
                DOOR_OPEN    <= '0'; -- Cerrar puerta
                display_timer_next <= 0;
                
                if tick_10hz_event = '1' then
                    if timer_reg < (target_count_reg - 1) then
                        timer_next <= timer_reg + 1;
                    else
                        current_garage_next <= 1;
                        target_garage_next  <= 1;
                        timer_next          <= 0;
                        target_count_next   <= 0;
                        state_next          <= S_IDLE;
                    end if;
                end if;
        end case;
    end process;
    
    -- Salidas
    LED_FULL_BLINK    <= led_full_state and parking_full;
    DISPLAY_VALUE_OUT <= display_value_reg when display_timer_reg > 0 else 0;

end Behavioral;