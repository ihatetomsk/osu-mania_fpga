module hdmi_top (
    input  logic        FPGA_CLK1_50, // Входной клок 50 МГц
    input  logic [0:0]  KEY,          // Кнопка сброса [0]
	 input  logic [1:0]  mode, //display resolution
	 input  logic [1:0]  speed_mode,
	 input  logic [1:0]  diff_mode,
	 
    
    // I2C для настройки чипа передатчика
    output logic        HDMI_I2C_SCL,
    inout  wire         HDMI_I2C_SDA,
    
    // Интерфейс HDMI (Видео)
	 input  logic        HDMI_TX_INT,  
    output logic        HDMI_TX_CLK,
    output logic        HDMI_TX_HS,
    output logic        HDMI_TX_VS,
    output logic        HDMI_TX_DE,
    output logic [23:0] HDMI_TX_D,
    output logic [3:0]  LED,          // Светодиоды для диагностики

    input  logic [3:0]  BTN,          // Игровые кнопки

    input  logic        uart_rx,      
    output logic        uart_tx    
);

    // Внутренние сигналы
    logic clk_25, clk_40, clk_65, pll_locked;
    logic ready;
    logic rst;

    // Активный высокий уровень сброса (кнопки на плате прижаты к 1)
    assign rst = ~KEY[0];

    // Удобная работа со встроенными кнопками (инверсия и разворот порядка)
    // logic [3:0] btn_active;
    // assign btn_active = ~BTN; 
    logic [3:0] btn_active;
    assign btn_active[0] = ~BTN[3]; // Физическая левая кнопка (BTN[3]) пойдет в 0-й канал UART (буква 'a')
    assign btn_active[1] = ~BTN[2]; // Вторая слева -> в 1-й канал (буква 's')
    assign btn_active[2] = ~BTN[1]; // Третья слева -> во 2-й канал (буква 'd')
    assign btn_active[3] = ~BTN[0]; // Физическая правая кнопка (BTN[0]) -> в 3-й канал (буква 'f')

    // Сигналы от модуля uart_display к игровой логике
    logic [3:0] keys_for_game;

    // Диагностика через светодиоды
    assign LED[0] = pll_locked;   // Горит, если PLL залочился и работает стабильно
    assign LED[1] = ready;        // Горит, если чип HDMI успешно настроен по I2C
    assign LED[3:2] = mode;      // Остальные выключаем

    // Генерация пиксельного клока 25.177 МГц из опорных 50 МГц
    p_pll pll_inst (
        .refclk   (FPGA_CLK1_50),
        .rst      (rst), 
        .outclk_0 (clk_25),
		  .outclk_1 (clk_40),
		  .outclk_2 (clk_65),
        .locked   (pll_locked)   
    );
		
	logic clk_pixel;
    always_comb begin
        case (mode)
            2'b00:   clk_pixel = clk_25;
            2'b01:   clk_pixel = clk_40;
            2'b10:   clk_pixel = clk_65;
            default: clk_pixel = clk_25;
        endcase
    end
	 
	 
	 /////////////////////////////
	 //hot plug detect

	 ///////////////////////////
	 
    // Конфигуратор чипа ADV7513
    hdmi_config cfg (
        .clk      (FPGA_CLK1_50),
        .rst      (i2c_auto_rst),
        .i2c_sclk (HDMI_I2C_SCL),
        .i2c_sdat (HDMI_I2C_SDA),
        .ready    (ready)        
    );

    // Генератор развертки VGA (640x480 @ 60Hz)
    logic [10:0] x, y;
    logic vga_de;
    
    vga_generator vga (
        .clk   (clk_pixel),
        .hsync (HDMI_TX_HS),
        .vsync (HDMI_TX_VS),
        .rst   (rst),
        .mode  (mode),
        .de    (vga_de),
        .x     (x),
        .y     (y)
    );

    logic [7:0] w_red, w_green, w_blue;
     
    // Модуль связи с ПК по UART и обработки нажатий
    uart_display uart_inst (
        .clk        (FPGA_CLK1_50),   // 50 МГц для генерации частоты UART (Baud Rate)
        .reset      (rst),            // Активный высокий сброс
        .rx         (uart_rx),
        .tx         (uart_tx),
        .but_1      (btn_active[0]),  // Физическая кнопка 1 -> сообщение 'a' в консоль
        .but_2      (btn_active[1]),  // Физическая кнопка 2 -> сообщение 's' в консоль
        .but_3      (btn_active[2]),  // Физическая кнопка 3 -> сообщение 'd' в консоль
        .but_4      (btn_active[3]),  // Физическая кнопка 4 -> сообщение 'f' in консоль
        .but_1_out  (keys_for_game[0]),
        .but_2_out  (keys_for_game[1]),
        .but_3_out  (keys_for_game[2]),
        .but_4_out  (keys_for_game[3])
    );
     
    // Игровая логика генерации графики (ядро игры)
    pattern_gen game_logic (
        .clk   (clk_pixel),
        .rst   (rst),
        .mode  (mode),
		  .speed_mode (speed_mode),
		  .spawn_mode (diff_mode),
        .x     (x),
        .y     (y),
        .de    (vga_de),
        .keys  (btn_active), //пока убрал keys_for_game ведь проблема в том что оно на один такт подает значения и не детектит удержание
        .r     (w_red),
        .g     (w_green),
        .b     (w_blue)
    );


    // Назначение выходных сигналов на разъем HDMI
    assign HDMI_TX_DE  = vga_de;
    assign HDMI_TX_D   = {w_red, w_green, w_blue}; // Формирование финальной 24-битной шины RGB
    assign HDMI_TX_CLK = clk_pixel;                  // Инверсия клока для фиксации данных чипом ADV7513

endmodule