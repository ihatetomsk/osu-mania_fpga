library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_tx is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        tx_tick  : in  std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        tx_start : in  std_logic;
        tx       : out std_logic;
        tx_busy  : out std_logic
    );
end entity;

architecture rtl of uart_tx is
    type state_type is (IDLE, START_BIT, DATA_BITS, PARITY_BIT, STOP_BIT);
    signal state      : state_type;
    signal tx_reg     : std_logic := '1';
    signal data_buf   : std_logic_vector(7 downto 0);
    signal bit_cnt    : integer range 0 to 7;
    signal parit_bit : std_logic;
begin
    tx <= tx_reg;

    process(tx_data)
        variable tmp : std_logic;
    begin
        tmp := '0';
        for i in 0 to 7 loop
            tmp := tmp xor tx_data(i);
        end loop;
        parit_bit <= tmp;   
                                
    end process;

    process(clk, reset)
    begin
        if reset = '1' then
            state   <= IDLE;
            tx_reg  <= '1';
            tx_busy    <= '0';
            bit_cnt <= 0;
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    tx_reg <= '1';
                    tx_busy <= '0';
                    if tx_start = '1' then
                        data_buf <= tx_data;
                        bit_cnt <= 0;
                        state   <= START_BIT;
                        tx_busy    <= '1';
                    end if;

                when START_BIT =>
                    if tx_tick = '1' then
                        tx_reg <= '0';
                        state  <= DATA_BITS;
                    end if;

                when DATA_BITS =>
                    if tx_tick = '1' then
                        tx_reg <= data_buf(0);          
                        data_buf <= '0' & data_buf(7 downto 1);
                        if bit_cnt = 7 then
                            state <= PARITY_BIT;
                            bit_cnt <= 0;
                        else
                            bit_cnt <= bit_cnt + 1;
                        end if;
                    end if;

                when PARITY_BIT =>
                    if tx_tick = '1' then
                        tx_reg <= parit_bit;
                        state <= STOP_BIT;
                    end if;

                when STOP_BIT =>
                    if tx_tick = '1' then
                        tx_reg <= '1';
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
end architecture;