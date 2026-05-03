module hdmi_top (
    input  logic       FPGA_CLK1_50, // 50РњР“С†
    input  logic [0:0] KEY,          // РљРЅРѕРїРєР° СЃР±СЂРѕСЃР° [0]
    
    // I2C РґР»СЏ РЅР°СЃС‚СЂРѕР№РєРё С‡РёРїР°
    output logic       HDMI_I2C_SCL,
    inout  wire        HDMI_I2C_SDA,
    
    // РґР»СЏ hdmi
    output logic       HDMI_TX_CLK,
    output logic       HDMI_TX_HS,
    output logic       HDMI_TX_VS,
    output logic       HDMI_TX_DE,
    output logic [23:0] HDMI_TX_D,
    output logic [3:0] LED ,          // СЃРІРµС‚РѕРґРёРѕРґС‹ РґР»СЏ РґРёР°РіРЅРѕСЃС‚РёРєРё

    input  logic[3:0] BTN //buttons users game control
);


    // СЃРёРіРЅР°Р»Рё РІРЅСѓС‚СЂРµРЅРЅРёРµ
    logic clk_25;
    logic pll_locked;
    logic ready;
    logic rst;
    
    assign rst = ~KEY[0];

	 //conveniant work with integral buttons
    logic [3:0] keys_active;
    assign keys_active = ~BTN; 

    // РґРёР°РіРѕРЅСЃС‚РёРєР° С‡РµСЂРµР· СЃРІРµС‚РѕРґРёРѕРґС‹
    assign LED[0] = pll_locked;   // Р“РѕСЂРёС‚, РµСЃР»Рё PLL СЂР°Р±РѕС‚Р°РµС‚
    assign LED[1] = ready;        // Р“РѕСЂРёС‚, РµСЃР»Рё С‡РёРї HDMI РЅР°СЃС‚СЂРѕРµРЅ РїРѕ I2C
    assign LED[3:2] = 2'b00;      // РћСЃС‚Р°Р»СЊРЅС‹Рµ РІС‹РєР»СЋС‡Р°РµРј

    // РёР· 50РњР“С† РґРµР»Р°РµРј 25.177РњР“С†
    my_pll pll_inst (
        .refclk   (FPGA_CLK1_50),
        .rst      (rst), 
        .outclk_0 (clk_25),      
        .locked   (pll_locked)   
    );

    // РёРЅРёС‚ adv7513
    hdmi_config cfg (
        .clk      (FPGA_CLK1_50),
        .rst      (rst),
        .i2c_sclk (HDMI_I2C_SCL),
        .i2c_sdat (HDMI_I2C_SDA),
        .ready    (ready)        
    );

    // РіРµРЅРµСЂР°С†РёСЏ 640x480
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
		  .keys (keys_active),
        .r   (w_red),
        .g   (w_green),
        .b   (w_blue)
    );
    // РіРµРЅРµСЂР°С†РёСЏ С‚СЂРµС… С†РІРµС‚РѕРІ
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