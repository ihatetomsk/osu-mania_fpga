library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_rx is
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        rx            : in  std_logic;
        rx_tick       : in  std_logic;
        rx_data       : out std_logic_vector(7 downto 0);
        rx_data_valid : out std_logic
    );
end uart_rx;

architecture behavioral of uart_rx is
    type state_type is (IDLE, START_DETECT, DATA_BITS, PARITY_BIT, STOP_BIT);
    signal state      : state_type := IDLE;
    signal sample_cnt : integer range 0 to 15 := 0;
    signal bit_cnt    : integer range 0 to 7  := 0;
    signal data_reg   : std_logic_vector(7 downto 0);
    signal parity_reg : std_logic;
    signal sync_rx    : std_logic_vector(1 downto 0);
    signal rx_sampled : std_logic;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            sync_rx <= sync_rx(0) & rx;
        end if;
    end process;
    rx_sampled <= sync_rx(1);

    process(clk, reset)
        variable parity_calc : std_logic;
    begin
        if reset = '1' then
            state         <= IDLE;
            sample_cnt    <= 0;
            bit_cnt       <= 0;
            data_reg      <= (others => '0');
            parity_reg    <= '0';
            rx_data       <= (others => '0');
            rx_data_valid <= '0';
        elsif rising_edge(clk) then
            rx_data_valid <= '0';
            if rx_tick = '1' then
                case state is
                    when IDLE =>
                        if rx_sampled = '0' then
                            state      <= START_DETECT;
                            sample_cnt <= 0;
                        end if;

                    when START_DETECT =>
                        if sample_cnt = 8 then
                            if rx_sampled = '0' then
                                state      <= DATA_BITS;
                                sample_cnt <= 0;   
                            else
                                state <= IDLE;
                            end if;
                        else
                            sample_cnt <= sample_cnt + 1;
                        end if;

                    when DATA_BITS =>
                        if sample_cnt = 8 then
                            data_reg(bit_cnt) <= rx_sampled;
                            if bit_cnt = 7 then
                                state    <= PARITY_BIT;
                                bit_cnt  <= 0;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        end if;
                        if sample_cnt = 15 then
                            sample_cnt <= 0;
                        else
                            sample_cnt <= sample_cnt + 1;
                        end if;

                    when PARITY_BIT =>
                        if sample_cnt = 8 then
                            parity_reg <= rx_sampled;
                            state      <= STOP_BIT;
                        end if;
                        if sample_cnt = 15 then
                            sample_cnt <= 0;
                        else
                            sample_cnt <= sample_cnt + 1;
                        end if;

                    when STOP_BIT =>
                        if sample_cnt = 8 then
                            parity_calc := data_reg(0) xor data_reg(1) xor data_reg(2) xor
                                           data_reg(3) xor data_reg(4) xor data_reg(5) xor
                                           data_reg(6) xor data_reg(7);
                            if rx_sampled = '1' and parity_reg = parity_calc then
                                rx_data       <= data_reg;
                                rx_data_valid <= '1';
                            end if;
                            state <= IDLE;
                        else
                            if sample_cnt = 15 then
                                sample_cnt <= 0;
                            else
                                sample_cnt <= sample_cnt + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end behavioral;