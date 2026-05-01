module hdmi_top (
    input  logic       FPGA_CLK1_50, // 50МГц
    input  logic [0:0] KEY,          // Кнопка сброса [0]
    
    // I2C для настройки чипа
    output logic       HDMI_I2C_SCL,
    inout  wire        HDMI_I2C_SDA,
    
    // для hdmi
    output logic       HDMI_TX_CLK,
    output logic       HDMI_TX_HS,
    output logic       HDMI_TX_VS,
    output logic       HDMI_TX_DE,
    output logic [23:0] HDMI_TX_D,
    output logic [3:0] LED           // светодиоды для диагностики
);

    // сигнали внутренние
    logic clk_25;
    logic pll_locked;
    logic ready;
    logic rst;
    
    assign rst = ~KEY[0];

    // диагонстика через светодиоды
    assign LED[0] = pll_locked;   // Горит, если PLL работает
    assign LED[1] = ready;        // Горит, если чип HDMI настроен по I2C
    assign LED[3:2] = 2'b00;      // Остальные выключаем

    // из 50МГц делаем 25.177МГц
    my_pll pll_inst (
        .refclk   (FPGA_CLK1_50),
        .rst      (rst), 
        .outclk_0 (clk_25),      
        .locked   (pll_locked)   
    );

    // инит adv7513
    hdmi_config cfg (
        .clk      (FPGA_CLK1_50),
        .rst      (rst),
        .i2c_sclk (HDMI_I2C_SCL),
        .i2c_sdat (HDMI_I2C_SDA),
        .ready    (ready)        
    );

    // генерация 640x480
    logic [9:0] x, y;
    logic vga_de;
    
    vga_generator vga (
        .clk   (clk_25),
        .hsync (HDMI_TX_HS),
        .vsync (HDMI_TX_VS),
        .de    (vga_de),
        .x     (x),
        .y     (y)
    );

	 logic [7:0] w_red, w_green, w_blue;
	 
	 pattern_gen game_logic (
        .clk (clk_25),
        .rst (rst),
        .x   (x),
        .y   (y),
        .de  (vga_de),
        .r   (w_red),
        .g   (w_green),
        .b   (w_blue)
    );
    // генерация трех цветов
//    always_comb begin
//        if (vga_de) begin
//            if (x < 213)      HDMI_TX_D = 24'h000000; 
//				else if(x>213 & x <= 215) HDMI_TX_D =24'hFFFFFF;
//            else if (x < 426 && x > 215) HDMI_TX_D = 24'h000000; 
//				else if(x >=426 & x<428)HDMI_TX_D =24'hFFFFFF;
//            else              HDMI_TX_D = 24'h000000; 
//        end else begin
//            HDMI_TX_D = 24'h000000;
//        end
//    end

    assign HDMI_TX_DE  = vga_de;
	 assign HDMI_TX_D   = {w_red, w_green, w_blue};
    assign HDMI_TX_CLK = ~clk_25; 

endmodule