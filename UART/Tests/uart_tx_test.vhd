library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_tx_test is
end entity;

architecture bench of uart_tx_test is
    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';   
    signal tx_tick    : std_logic := '0';
    signal tx_data    : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start   : std_logic := '0';
    signal tx         : std_logic;
    signal tx_busy    : std_logic;

    constant CLK_PERIOD : time := 20 ns;
    constant BIT_PERIOD : time := 200 us;

    function to_hex_str(v : std_logic_vector(7 downto 0)) return string is
        constant hex_char : string := "0123456789ABCDEF";
        variable result   : string(1 to 2);
    begin
        result(1) := hex_char(to_integer(unsigned(v(7 downto 4)))+1);
        result(2) := hex_char(to_integer(unsigned(v(3 downto 0)))+1);
        return result;
    end function;
begin
    clk <= not clk after CLK_PERIOD/2;

    -- Генератор tx_tick
    tx_tick_process : process
    begin
        while true loop
            wait for BIT_PERIOD - CLK_PERIOD/2;
            tx_tick <= '1';
            wait for CLK_PERIOD;
            tx_tick <= '0';
        end loop;
    end process;

    -- Сброс: активен 100 нс, затем 0
    reset <= '1', '0' after 100 ns;

    test_process : process
        procedure send_byte_and_check (data : std_logic_vector(7 downto 0)) is
            variable parity : std_logic;
        begin
            parity := '0';
            for i in 0 to 7 loop parity := parity xor data(i); end loop;

            wait until tx_busy = '0' and rising_edge(clk);
            tx_data <= data;
            tx_start <= '1';
            wait until rising_edge(clk);
            tx_start <= '0';
            wait until tx_busy = '1' and rising_edge(clk);

            wait for BIT_PERIOD;
            assert tx = '0' report "Start bit error for " & to_hex_str(data) severity error;

            for bit_idx in 0 to 7 loop
                wait for BIT_PERIOD;
                assert tx = data(bit_idx)
                    report "Data bit error for " & to_hex_str(data) severity error;
            end loop;

            wait for BIT_PERIOD;
            assert tx = parity report "Parity error for " & to_hex_str(data) severity error;

            wait for BIT_PERIOD;
            assert tx = '1' report "Stop bit error for " & to_hex_str(data) severity error;

            wait until tx_busy = '0' and rising_edge(clk);
            report "Transmission of " & to_hex_str(data) & " OK" severity note;
        end procedure;

    begin
        wait until reset = '0';
        wait for 1 us;

        send_byte_and_check(x"55");
        send_byte_and_check(x"00");
        send_byte_and_check(x"FF");
        send_byte_and_check(x"01");
        send_byte_and_check(x"80");
        send_byte_and_check(x"A5");

        report "All basic tests passed" severity note;
        wait;
    end process;

    UUT: entity work.uart_tx
        port map (
            clk      => clk,
            reset    => reset,
            tx_tick  => tx_tick,
            tx_data  => tx_data,
            tx_start => tx_start,
            tx       => tx,
            tx_busy  => tx_busy
        );
end architecture;