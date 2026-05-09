library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; 

entity uart_display is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        rx    : in  std_logic;
        tx    : out std_logic;
		  
		  but_1 : in  std_logic;   
        but_2 : in  std_logic;   
        but_3 : in  std_logic;   
        but_4 : in  std_logic;
		  
		  but_1_out : out  std_logic;   
        but_2_out : out  std_logic;   
        but_3_out : out  std_logic;   
        but_4_out : out  std_logic 
    );
end uart_display;

architecture behavioral of uart_display is
    signal tx_tick : std_logic;
    signal rx_tick : std_logic;
    signal rx_data : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal tx_data : std_logic_vector(7 downto 0);
    signal tx_start : std_logic;
    signal tx_busy : std_logic;
	 
	 signal but1_reg : std_logic_vector(1 downto 0) := "00";
    signal but2_reg : std_logic_vector(1 downto 0) := "00";
    signal but3_reg : std_logic_vector(1 downto 0) := "00";
    signal but4_reg : std_logic_vector(1 downto 0) := "00";
    signal but1_rise, but2_rise, but3_rise, but4_rise : std_logic;
	 
	 type chars_array_t is array (0 to 100) of std_logic_vector(7 downto 0);
    signal message : chars_array_t;
    signal msg_len : integer range 0 to 101 := 0;
	 
	 signal char_index : integer range 0 to 101 := 0;
	 
	 type send_state_type is (IDLE, LOAD_CHAR, WAIT_START, WAIT_END, WAIT_TX);
    signal state : send_state_type := IDLE;
	 
	 	function to_ascii(str : string; len : integer) return chars_array_t is
			 variable result : chars_array_t := (others => (others => '0'));
		begin
			 for i in 0 to len-1 loop
				  result(i) := std_logic_vector(to_unsigned(character'pos(str(i+1)), 8));
			 end loop;
			 return result;
		end function;

begin
    baud_gen_inst : entity work.baud_rate_gen
        port map (clk => clk, reset => reset, tx_tick => tx_tick, rx_tick => rx_tick);

    uart_rx_inst : entity work.uart_rx
        port map (clk => clk, reset => reset, rx => rx, rx_tick => rx_tick,
                  rx_data => rx_data, rx_data_valid => rx_valid);

    uart_tx_inst : entity work.uart_tx
        port map (clk => clk, reset => reset, tx_tick => tx_tick, tx_data => tx_data,
                  tx_start => tx_start, tx => tx, tx_busy => tx_busy);
						


    process(clk, reset)
    begin
        if reset = '1' then
            but1_reg <= "00";
            but2_reg <= "00";
            but3_reg <= "00";
            but4_reg <= "00";
        elsif rising_edge(clk) then
            but1_reg <= but1_reg(0) & but_1;
            but2_reg <= but2_reg(0) & but_2;
            but3_reg <= but3_reg(0) & but_3;
            but4_reg <= but4_reg(0) & but_4;
        end if;
    end process;

    but1_rise <= '1' when but1_reg = "01" else '0';
    but2_rise <= '1' when but2_reg = "01" else '0';
    but3_rise <= '1' when but3_reg = "01" else '0';
    but4_rise <= '1' when but4_reg = "01" else '0';
	 
	process(clk)
	
	begin
		if rising_edge(clk) then
			case state is
				when IDLE => 
					if rx_valid = '1' then
						if rx_data = x"61" then      
							message <= to_ascii("a is pressed", 12);
							message(12) <= x"0D";
                     message(13) <= x"0A";
							msg_len    <= 14;
							but_4_out <= '1';
							
						elsif rx_data = x"73" then   
							message <= to_ascii("s is pressed", 12);
							message(12) <= x"0D";
                     message(13) <= x"0A";
							msg_len    <= 14;
							but_3_out <= '1';
							
						elsif rx_data = x"64" then   
							message <= to_ascii("d is pressed", 12);
							message(12) <= x"0D";
                     message(13) <= x"0A";
							msg_len    <= 14;
							but_2_out <= '1';
						
						elsif rx_data = x"66" then   
							message <= to_ascii("f is pressed", 12);
							message(12) <= x"0D";
                     message(13) <= x"0A";
							msg_len    <= 14;
							but_1_out <= '1';
							
						elsif rx_data = x"0D" then   
							message <= to_ascii("ENTER is pressed", 16);
							message(16) <= x"0D";
                     message(17) <= x"0A";
							msg_len    <= 18;
							
						else
							message <= to_ascii("unknown is pressed", 18);
							message(18) <= x"0D";
                     message(19) <= x"0A";
							msg_len    <= 20;
						end if;
						
						state <= LOAD_CHAR;
						char_index <= 0;
						
					elsif but4_rise = '1' then

                        message <= to_ascii("a is pressed", 12);
                        message(12) <= x"0D";
                        message(13) <= x"0A";
                        msg_len <= 14;
                        state <= LOAD_CHAR;
                        char_index <= 0;
								but_4_out <= '1';

                    elsif but3_rise = '1' then
                        message <= to_ascii("s is pressed", 12);
                        message(12) <= x"0D";
                        message(13) <= x"0A";
                        msg_len <= 14;
                        state <= LOAD_CHAR;
                        char_index <= 0;
								but_3_out <= '1';

                    elsif but2_rise = '1' then
                        message <= to_ascii("d is pressed", 12);
                        message(12) <= x"0D";
                        message(13) <= x"0A";
                        msg_len <= 14;
                        state <= LOAD_CHAR;
                        char_index <= 0;
								but_2_out <= '1';

                    elsif but1_rise = '1' then
                        message <= to_ascii("f is pressed", 12);
                        message(12) <= x"0D";
                        message(13) <= x"0A";
                        msg_len <= 14;
                        state <= LOAD_CHAR;
                        char_index <= 0;
								but_1_out <= '1';

					end if;
				
				when LOAD_CHAR => 
					tx_data <= message(char_index);
					char_index <= char_index + 1;
					state <= WAIT_START;
					
				when WAIT_START =>
					but_1_out <= '0';
					but_2_out <= '0';
					but_3_out <= '0';
					but_4_out <= '0';
					tx_start <= '1';
					state <= WAIT_END;
					
				when WAIT_END =>
					if tx_busy = '1' then
						tx_start <= '0';
						state    <= WAIT_TX;
					end if;

				when WAIT_TX =>
					if tx_busy = '0' then
						if char_index = msg_len then
							state <= IDLE;
						else
							state <= LOAD_CHAR;
						end if;
					end if;
					
			end case;
		end if;
	end process;
 
	 
end behavioral;