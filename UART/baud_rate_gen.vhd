library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity baud_rate_gen is
    generic (
        CLK_FREQ  : integer := 50000000;
        BAUD_RATE : integer := 5000
    );
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        tx_tick : out std_logic;   
        rx_tick : out std_logic    
    );
end baud_rate_gen;

architecture behavioral of baud_rate_gen is
    constant TX_DIV : integer := CLK_FREQ / BAUD_RATE;
    constant RX_DIV : integer := CLK_FREQ / (BAUD_RATE * 16);
    signal tx_count : integer range 0 to TX_DIV - 1 := 0;
    signal rx_count : integer range 0 to RX_DIV - 1 := 0;
begin
    -- Tx tick
    process(clk, reset)
    begin
        if reset = '1' then
            tx_count <= 0;
            tx_tick  <= '0';
        elsif rising_edge(clk) then
            if tx_count = TX_DIV - 1 then
                tx_count <= 0;
                tx_tick  <= '1';
            else
                tx_count <= tx_count + 1;
                tx_tick  <= '0';
            end if;
        end if;
    end process;

    -- Rx tick
    process(clk, reset)
    begin
        if reset = '1' then
            rx_count <= 0;
            rx_tick  <= '0';
        elsif rising_edge(clk) then
            if rx_count = RX_DIV - 1 then
                rx_count <= 0;
                rx_tick  <= '1';
            else
                rx_count <= rx_count + 1;
                rx_tick  <= '0';
            end if;
        end if;
    end process;
end behavioral;
