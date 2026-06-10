library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_rx_test is
end entity;

architecture bench of uart_rx_test is
    signal clk           : std_logic := '0';
    signal reset         : std_logic;
    signal rx            : std_logic := '1';
    signal rx_tick       : std_logic := '0';
    signal rx_data       : std_logic_vector(7 downto 0);
    signal rx_data_valid : std_logic;

    constant CLK_PERIOD   : time := 20 ns;
    constant BIT_PERIOD   : time := 8.68 us;     -- 115200 бод
    constant OVERSAMPLING : integer := 16;
    constant TICK_PERIOD  : time := BIT_PERIOD / OVERSAMPLING; -- 542.5 ns

    signal valid_detected : boolean := false;
begin
    clk <= not clk after CLK_PERIOD/2;

    -- Генератор rx_tick (16 импульсов на бит)
    rx_tick_process : process
    begin
        while true loop
            wait for TICK_PERIOD - CLK_PERIOD/2;
            rx_tick <= '1';
            wait for CLK_PERIOD;
            rx_tick <= '0';
        end loop;
    end process;

    -- Сброс: 200 нс активный '1', затем '0'
    reset <= '1', '0' after 200 ns;

    -- Отдельный процесс для обнаружения rx_data_valid
    process(rx_data_valid)
    begin
        if rx_data_valid = '1' then
            valid_detected <= true;
            report "rx_data_valid detected at " & time'image(now) severity note;
        end if;
    end process;

    test_process : process
        procedure send_byte (
            data         : std_logic_vector(7 downto 0);
            force_parity : integer := -1;
            force_stop   : integer := -1
        ) is
            variable parity : std_logic;
            variable stop   : std_logic;
        begin
            parity := '0';
            for i in 0 to 7 loop parity := parity xor data(i); end loop;
            if force_parity = 0 then parity := '0';
            elsif force_parity = 1 then parity := '1';
            end if;
            if force_stop = 0 then stop := '0';
            elsif force_stop = 1 then stop := '1';
            else stop := '1';
            end if;

            rx <= '0';
            wait for BIT_PERIOD;
            for i in 0 to 7 loop
                rx <= data(i);
                wait for BIT_PERIOD;
            end loop;
            rx <= parity;
            wait for BIT_PERIOD;
            rx <= stop;
            wait for BIT_PERIOD;
            rx <= '1';
            wait for BIT_PERIOD;
        end procedure;

    begin
        report "=== test_process started ===" severity note;
        wait until reset = '0';
        wait for 1 us;

        report "Sending 0x55" severity note;
        send_byte(x"55", -1, -1);
        
        report "Sending 0x80" severity note;
        send_byte(x"80", -1, -1);
        
        report "Sending 0xFF" severity note;
        send_byte(x"FF", -1, -1);

        wait for BIT_PERIOD * 5;

        if valid_detected then
            report "========== TEST PASSED ==========" severity note;
        else
            report "========== TEST FAILED: rx_data_valid never occurred ==========" severity error;
        end if;
        wait;
    end process;

    UUT: entity work.uart_rx
        port map (
            clk           => clk,
            reset         => reset,
            rx            => rx,
            rx_tick       => rx_tick,
            rx_data       => rx_data,
            rx_data_valid => rx_data_valid
        );
end architecture;