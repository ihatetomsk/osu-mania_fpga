library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_display is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        rx    : in  std_logic;
        tx    : out std_logic;

        -- Физические кнопки (игровые)
        but_1 : in  std_logic;
        but_2 : in  std_logic;
        but_3 : in  std_logic;
        but_4 : in  std_logic;

        -- Выходы для игровой логики
        but_1_out : out std_logic;
        but_2_out : out std_logic;
        but_3_out : out std_logic;
        but_4_out : out std_logic;

        -- Переключатели режимов (с платы)
        mode_sw      : in  std_logic_vector(1 downto 0);
        speed_mode_sw : in  std_logic_vector(1 downto 0);
        diff_mode_sw  : in  std_logic_vector(1 downto 0);

        -- Управляемые выходы для HDMI-топа
        mode_out      : out std_logic_vector(1 downto 0);
        speed_mode_out : out std_logic_vector(1 downto 0);
        diff_mode_out  : out std_logic_vector(1 downto 0);

        -- Импульс сброса (Enter)
        reset_pulse   : out std_logic
    );
end uart_display;

architecture behavioral of uart_display is
    -- UART
    signal tx_tick, rx_tick : std_logic;
    signal rx_data : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal tx_data : std_logic_vector(7 downto 0);
    signal tx_start : std_logic;
    signal tx_busy : std_logic;

    -- Кнопки (синхронизация)
    signal but1_reg, but2_reg, but3_reg, but4_reg : std_logic_vector(1 downto 0);
    signal but1_sync, but2_sync, but3_sync, but4_sync : std_logic;
    signal but1_prev, but2_prev, but3_prev, but4_prev : std_logic;

    -- UART latch для игровых клавиш
    signal uart_out_1, uart_out_2, uart_out_3, uart_out_4 : std_logic := '0';
    signal press_a, press_s, press_d, press_f : std_logic;
    signal release_a, release_s, release_d, release_f : std_logic;

    -- Декодер пакетов (два байта) генерирует импульсы управления
    type packet_state_t is (WAIT_FIRST, WAIT_SECOND);
    signal pstate : packet_state_t := WAIT_FIRST;
    signal first_byte : std_logic_vector(7 downto 0);
    
    -- Управляющие импульсы от декодера
    signal inc_mode, dec_mode : std_logic;
    signal inc_speed, dec_speed : std_logic;
    signal inc_diff, dec_diff : std_logic;
    signal cmd_reset : std_logic;

    -- Специальные коды управляющих клавиш
    constant KEY_UP    : std_logic_vector(7 downto 0) := x"80";
    constant KEY_DOWN  : std_logic_vector(7 downto 0) := x"81";
    constant KEY_LEFT  : std_logic_vector(7 downto 0) := x"82";
    constant KEY_RIGHT : std_logic_vector(7 downto 0) := x"83";
    constant KEY_PLUS  : std_logic_vector(7 downto 0) := x"2B";
    constant KEY_MINUS : std_logic_vector(7 downto 0) := x"2D";
    constant KEY_ENTER : std_logic_vector(7 downto 0) := x"0D";

    -- Регистры настроек (изменяемые по UART)
    signal mode_reg      : std_logic_vector(1 downto 0);
    signal speed_reg     : std_logic_vector(1 downto 0);
    signal diff_reg      : std_logic_vector(1 downto 0);
    signal reset_int     : std_logic;

    -- Сообщения для отправки
    type msg_type_t is (MSG_NONE, MSG_A, MSG_S, MSG_D, MSG_F,
                        MSG_MODE, MSG_SPEED, MSG_DIFF, MSG_RESET);
    signal current_msg : msg_type_t := MSG_NONE;
    signal char_index : integer range 0 to 50 := 0;
    signal msg_length : integer range 0 to 50 := 0;

    type send_state_type is (IDLE, LOAD_CHAR, WAIT_START, WAIT_END, WAIT_TX);
    signal state : send_state_type := IDLE;

    -- Вспомогательные функции
    impure function char_at(str : string; idx : positive) return std_logic_vector is
    begin
        if idx <= str'length then
            return std_logic_vector(to_unsigned(character'pos(str(idx)), 8));
        else
            return x"00";
        end if;
    end function;

    function value_to_ascii(v : std_logic_vector(1 downto 0)) return std_logic_vector is
    begin
        case v is
            when "00" => return x"30"; -- '0'
            when "01" => return x"31"; -- '1'
            when "10" => return x"32"; -- '2'
            when "11" => return x"33"; -- '3'
            when others => return x"30";
        end case;
    end function;

begin
    -- UART components
    baud_gen_inst : entity work.baud_rate_gen
        port map (clk => clk, reset => reset, tx_tick => tx_tick, rx_tick => rx_tick);
    uart_rx_inst : entity work.uart_rx
        port map (clk => clk, reset => reset, rx => rx, rx_tick => rx_tick,
                  rx_data => rx_data, rx_data_valid => rx_valid);
    uart_tx_inst : entity work.uart_tx
        port map (clk => clk, reset => reset, tx_tick => tx_tick, tx_data => tx_data,
                  tx_start => tx_start, tx => tx, tx_busy => tx_busy);

    -- Кнопки (синхронизация)
    process(clk, reset)
    begin
        if reset = '1' then
            but1_reg <= "00"; but2_reg <= "00"; but3_reg <= "00"; but4_reg <= "00";
            but1_prev <= '0'; but2_prev <= '0'; but3_prev <= '0'; but4_prev <= '0';
        elsif rising_edge(clk) then
            but1_reg <= but1_reg(0) & but_1;
            but2_reg <= but2_reg(0) & but_2;
            but3_reg <= but3_reg(0) & but_3;
            but4_reg <= but4_reg(0) & but_4;
            but1_prev <= but1_sync;
            but2_prev <= but2_sync;
            but3_prev <= but3_sync;
            but4_prev <= but4_sync;
        end if;
    end process;
    but1_sync <= but1_reg(1);
    but2_sync <= but2_reg(1);
    but3_sync <= but3_reg(1);
    but4_sync <= but4_reg(1);

    -- Выходы игровых клавиш (физическая кнопка ИЛИ удержание с UART)
    but_1_out <= but1_sync or uart_out_1;
    but_2_out <= but2_sync or uart_out_2;
    but_3_out <= but3_sync or uart_out_3;
    but_4_out <= but4_sync or uart_out_4;

    -- Декодер двухбайтовых пакетов (только генерирует импульсы, не присваивает регистры)
    process(clk, reset)
    begin
        if reset = '1' then
            pstate <= WAIT_FIRST;
            press_a <= '0'; press_s <= '0'; press_d <= '0'; press_f <= '0';
            release_a <= '0'; release_s <= '0'; release_d <= '0'; release_f <= '0';
            inc_mode <= '0'; dec_mode <= '0';
            inc_speed <= '0'; dec_speed <= '0';
            inc_diff <= '0'; dec_diff <= '0';
            cmd_reset <= '0';
        elsif rising_edge(clk) then
            -- Сброс импульсов
            press_a <= '0'; press_s <= '0'; press_d <= '0'; press_f <= '0';
            release_a <= '0'; release_s <= '0'; release_d <= '0'; release_f <= '0';
            inc_mode <= '0'; dec_mode <= '0';
            inc_speed <= '0'; dec_speed <= '0';
            inc_diff <= '0'; dec_diff <= '0';
            cmd_reset <= '0';

            if rx_valid = '1' then
                case pstate is
                    when WAIT_FIRST =>
                        first_byte <= rx_data;
                        pstate <= WAIT_SECOND;
                    when WAIT_SECOND =>
                        pstate <= WAIT_FIRST;
                        if rx_data = x"01" then   -- нажатие
                            case first_byte is
                                when x"61" => press_a <= '1';
                                when x"73" => press_s <= '1';
                                when x"64" => press_d <= '1';
                                when x"66" => press_f <= '1';
                                when KEY_UP   => inc_speed <= '1';
                                when KEY_DOWN => dec_speed <= '1';
                                when KEY_RIGHT=> inc_diff <= '1';
                                when KEY_LEFT => dec_diff <= '1';
                                when KEY_PLUS => inc_mode <= '1';
                                when KEY_MINUS=> dec_mode <= '1';
                                when KEY_ENTER=> cmd_reset <= '1';
                                when others => null;
                            end case;
                        elsif rx_data = x"00" then   -- отпускание
                            case first_byte is
                                when x"61" => release_a <= '1';
                                when x"73" => release_s <= '1';
                                when x"64" => release_d <= '1';
                                when x"66" => release_f <= '1';
                                when others => null;
                            end case;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- Защёлки для игровых клавиш (только press/release)
    process(clk, reset)
    begin
        if reset = '1' then
            uart_out_1 <= '0'; uart_out_2 <= '0'; uart_out_3 <= '0'; uart_out_4 <= '0';
        elsif rising_edge(clk) then
            if press_a = '1'   then uart_out_1 <= '1'; end if;
            if release_a = '1' then uart_out_1 <= '0'; end if;
            if press_s = '1'   then uart_out_2 <= '1'; end if;
            if release_s = '1' then uart_out_2 <= '0'; end if;
            if press_d = '1'   then uart_out_3 <= '1'; end if;
            if release_d = '1' then uart_out_3 <= '0'; end if;
            if press_f = '1'   then uart_out_4 <= '1'; end if;
            if release_f = '1' then uart_out_4 <= '0'; end if;
        end if;
    end process;

    -- Основной процесс: управление режимами, отправка сообщений, всё в одном месте
    process(clk, reset)
        variable new_mode : unsigned(1 downto 0);
        variable new_speed : unsigned(1 downto 0);
        variable new_diff : unsigned(1 downto 0);
    begin
        if reset = '1' then
            mode_reg   <= mode_sw;
            speed_reg  <= speed_mode_sw;
            diff_reg   <= diff_mode_sw;
            reset_int  <= '0';
            current_msg <= MSG_NONE;
            char_index <= 0;
            msg_length <= 0;
            state <= IDLE;
            tx_start <= '0';
        elsif rising_edge(clk) then
            -- По умолчанию сбрасываем импульс сброса (он длится один такт)
            reset_int <= '0';
            tx_start <= '0';

            case state is
                when IDLE =>
                    -- Обработка изменения режимов по UART-импульсам
                    if inc_mode = '1' then
                        new_mode := unsigned(mode_reg) + 1;
                        mode_reg <= std_logic_vector(new_mode);
                        current_msg <= MSG_MODE;
                        msg_length <= 8;    -- "mode=X" + CRLF (X - цифра)
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif dec_mode = '1' then
                        new_mode := unsigned(mode_reg) - 1;
                        mode_reg <= std_logic_vector(new_mode);
                        current_msg <= MSG_MODE;
                        msg_length <= 8;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif inc_speed = '1' then
                        new_speed := unsigned(speed_reg) + 1;
                        speed_reg <= std_logic_vector(new_speed);
                        current_msg <= MSG_SPEED;
                        msg_length <= 9;    -- "speed=X" + CRLF
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif dec_speed = '1' then
                        new_speed := unsigned(speed_reg) - 1;
                        speed_reg <= std_logic_vector(new_speed);
                        current_msg <= MSG_SPEED;
                        msg_length <= 9;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif inc_diff = '1' then
                        new_diff := unsigned(diff_reg) + 1;
                        diff_reg <= std_logic_vector(new_diff);
                        current_msg <= MSG_DIFF;
                        msg_length <= 7;    -- "diff=X" + CRLF
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif dec_diff = '1' then
                        new_diff := unsigned(diff_reg) - 1;
                        diff_reg <= std_logic_vector(new_diff);
                        current_msg <= MSG_DIFF;
                        msg_length <= 7;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif cmd_reset = '1' then
                        reset_int <= '1';
                        current_msg <= MSG_RESET;
                        msg_length <= 7;    -- "reset" + CRLF
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    -- Нажатия игровых клавиш (UART press)
                    elsif press_a = '1' and uart_out_1 = '0' then
                        current_msg <= MSG_A;
                        msg_length <= 14;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif press_s = '1' and uart_out_2 = '0' then
                        current_msg <= MSG_S;
                        msg_length <= 14;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif press_d = '1' and uart_out_3 = '0' then
                        current_msg <= MSG_D;
                        msg_length <= 14;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif press_f = '1' and uart_out_4 = '0' then
                        current_msg <= MSG_F;
                        msg_length <= 14;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    -- Физические кнопки (фронты)
                    elsif but1_sync = '1' and but1_prev = '0' then
                        current_msg <= MSG_A;
                        msg_length <= 14;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif but2_sync = '1' and but2_prev = '0' then
                        current_msg <= MSG_S;
                        msg_length <= 14;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif but3_sync = '1' and but3_prev = '0' then
                        current_msg <= MSG_D;
                        msg_length <= 14;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    elsif but4_sync = '1' and but4_prev = '0' then
                        current_msg <= MSG_F;
                        msg_length <= 14;
                        char_index <= 0;
                        state <= LOAD_CHAR;
                    end if;

                when LOAD_CHAR =>
                    -- Генерация следующего символа
                    case current_msg is
                        when MSG_A =>
                            case char_index is
                                when 0 => tx_data <= char_at("a is pressed", 1);
                                when 1 => tx_data <= char_at("a is pressed", 2);
                                when 2 => tx_data <= char_at("a is pressed", 3);
                                when 3 => tx_data <= char_at("a is pressed", 4);
                                when 4 => tx_data <= char_at("a is pressed", 5);
                                when 5 => tx_data <= char_at("a is pressed", 6);
                                when 6 => tx_data <= char_at("a is pressed", 7);
                                when 7 => tx_data <= char_at("a is pressed", 8);
                                when 8 => tx_data <= char_at("a is pressed", 9);
                                when 9 => tx_data <= char_at("a is pressed", 10);
                                when 10 => tx_data <= char_at("a is pressed", 11);
                                when 11 => tx_data <= char_at("a is pressed", 12);
                                when 12 => tx_data <= x"0D";
                                when 13 => tx_data <= x"0A";
                                when others => tx_data <= x"00";
                            end case;
                        when MSG_S =>
                            case char_index is
                                when 0 => tx_data <= char_at("s is pressed", 1);
                                when 1 => tx_data <= char_at("s is pressed", 2);
                                when 2 => tx_data <= char_at("s is pressed", 3);
                                when 3 => tx_data <= char_at("s is pressed", 4);
                                when 4 => tx_data <= char_at("s is pressed", 5);
                                when 5 => tx_data <= char_at("s is pressed", 6);
                                when 6 => tx_data <= char_at("s is pressed", 7);
                                when 7 => tx_data <= char_at("s is pressed", 8);
                                when 8 => tx_data <= char_at("s is pressed", 9);
                                when 9 => tx_data <= char_at("s is pressed", 10);
                                when 10 => tx_data <= char_at("s is pressed", 11);
                                when 11 => tx_data <= char_at("s is pressed", 12);
                                when 12 => tx_data <= x"0D";
                                when 13 => tx_data <= x"0A";
                                when others => tx_data <= x"00";
                            end case;
                        when MSG_D =>
                            case char_index is
                                when 0 => tx_data <= char_at("d is pressed", 1);
                                when 1 => tx_data <= char_at("d is pressed", 2);
                                when 2 => tx_data <= char_at("d is pressed", 3);
                                when 3 => tx_data <= char_at("d is pressed", 4);
                                when 4 => tx_data <= char_at("d is pressed", 5);
                                when 5 => tx_data <= char_at("d is pressed", 6);
                                when 6 => tx_data <= char_at("d is pressed", 7);
                                when 7 => tx_data <= char_at("d is pressed", 8);
                                when 8 => tx_data <= char_at("d is pressed", 9);
                                when 9 => tx_data <= char_at("d is pressed", 10);
                                when 10 => tx_data <= char_at("d is pressed", 11);
                                when 11 => tx_data <= char_at("d is pressed", 12);
                                when 12 => tx_data <= x"0D";
                                when 13 => tx_data <= x"0A";
                                when others => tx_data <= x"00";
                            end case;
                        when MSG_F =>
                            case char_index is
                                when 0 => tx_data <= char_at("f is pressed", 1);
                                when 1 => tx_data <= char_at("f is pressed", 2);
                                when 2 => tx_data <= char_at("f is pressed", 3);
                                when 3 => tx_data <= char_at("f is pressed", 4);
                                when 4 => tx_data <= char_at("f is pressed", 5);
                                when 5 => tx_data <= char_at("f is pressed", 6);
                                when 6 => tx_data <= char_at("f is pressed", 7);
                                when 7 => tx_data <= char_at("f is pressed", 8);
                                when 8 => tx_data <= char_at("f is pressed", 9);
                                when 9 => tx_data <= char_at("f is pressed", 10);
                                when 10 => tx_data <= char_at("f is pressed", 11);
                                when 11 => tx_data <= char_at("f is pressed", 12);
                                when 12 => tx_data <= x"0D";
                                when 13 => tx_data <= x"0A";
                                when others => tx_data <= x"00";
                            end case;
                        when MSG_MODE =>
                            case char_index is
                                when 0 => tx_data <= char_at("mode=", 1);
                                when 1 => tx_data <= char_at("mode=", 2);
                                when 2 => tx_data <= char_at("mode=", 3);
                                when 3 => tx_data <= char_at("mode=", 4);
                                when 4 => tx_data <= char_at("mode=", 5);
                                when 5 => tx_data <= value_to_ascii(mode_reg);
                                when 6 => tx_data <= x"0D";
                                when 7 => tx_data <= x"0A";
                                when others => tx_data <= x"00";
                            end case;
                        when MSG_SPEED =>
                            case char_index is
                                when 0 => tx_data <= char_at("speed=", 1);
                                when 1 => tx_data <= char_at("speed=", 2);
                                when 2 => tx_data <= char_at("speed=", 3);
                                when 3 => tx_data <= char_at("speed=", 4);
                                when 4 => tx_data <= char_at("speed=", 5);
                                when 5 => tx_data <= char_at("speed=", 6);
                                when 6 => tx_data <= value_to_ascii(speed_reg);
                                when 7 => tx_data <= x"0D";
                                when 8 => tx_data <= x"0A";
                                when others => tx_data <= x"00";
                            end case;
                        when MSG_DIFF =>
                            case char_index is
                                when 0 => tx_data <= char_at("diff=", 1);
                                when 1 => tx_data <= char_at("diff=", 2);
                                when 2 => tx_data <= char_at("diff=", 3);
                                when 3 => tx_data <= char_at("diff=", 4);
                                when 4 => tx_data <= char_at("diff=", 5);
                                when 5 => tx_data <= value_to_ascii(diff_reg);
                                when 6 => tx_data <= x"0D";
                                when 7 => tx_data <= x"0A";
                                when others => tx_data <= x"00";
                            end case;
                        when MSG_RESET =>
                            case char_index is
                                when 0 => tx_data <= char_at("reset", 1);
                                when 1 => tx_data <= char_at("reset", 2);
                                when 2 => tx_data <= char_at("reset", 3);
                                when 3 => tx_data <= char_at("reset", 4);
                                when 4 => tx_data <= char_at("reset", 5);
                                when 5 => tx_data <= x"0D";
                                when 6 => tx_data <= x"0A";
                                when others => tx_data <= x"00";
                            end case;
                        when others =>
                            tx_data <= x"00";
                    end case;
                    char_index <= char_index + 1;
                    state <= WAIT_START;

                when WAIT_START =>
                    tx_start <= '1';
                    state <= WAIT_END;

                when WAIT_END =>
                    if tx_busy = '1' then
                        tx_start <= '0';
                        state <= WAIT_TX;
                    end if;

                when WAIT_TX =>
                    if tx_busy = '0' then
                        if char_index = msg_length then
                            state <= IDLE;
                            current_msg <= MSG_NONE;
                        else
                            state <= LOAD_CHAR;
                        end if;
                    end if;
            end case;
        end if;
    end process;

    -- Выходы
    mode_out      <= mode_reg;
    speed_mode_out <= speed_reg;
    diff_mode_out  <= diff_reg;
    reset_pulse   <= reset_int;

end behavioral;