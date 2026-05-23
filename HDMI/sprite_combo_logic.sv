module sprite_combo (
    input  logic [10:0] x,            
    input  logic [10:0] y,             
    input  logic [3:0]  combo_ones,     
    input  logic [3:0]  combo_tens,    
    input  logic [3:0]  combo_hundreds,  
    input  logic [3:0]  top_ones,       
    input  logic [3:0]  top_tens,        
    input  logic [3:0]  top_hundreds,    
    output logic [1:0]  text_pixel       // 0=пусто, 1=комбо, 2= топ скор
);

    // font (8x16 пикселей для каждой цифры
    logic [7:0] font_rom [0:12][0:15];
    initial begin
        font_rom[0] = '{8'h3C, 8'h66, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'h66, 8'h3C, 8'h00}; //0
        font_rom[1] = '{8'h18, 8'h38, 8'h78, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h7E, 8'h00}; //1
        font_rom[2] = '{8'h3C, 8'h66, 8'hC3, 8'hC3, 8'h03, 8'h06, 8'h0C, 8'h18, 8'h30, 8'h60, 8'hC0, 8'hC0, 8'hC0, 8'hC0, 8'hFF, 8'h00}; //2
        font_rom[3] = '{8'h3C, 8'h66, 8'hC3, 8'h03, 8'h03, 8'h03, 8'h1E, 8'h03, 8'h03, 8'h03, 8'h03, 8'h03, 8'hC3, 8'h66, 8'h3C, 8'h00}; //3
        font_rom[4] = '{8'h0C, 8'h1C, 8'h3C, 8'h6C, 8'hCC, 8'hCC, 8'hCC, 8'hFF, 8'h0C, 8'h0C, 8'h0C, 8'h0C, 8'h0C, 8'h0C, 8'h0C, 8'h00}; //4
        font_rom[5] = '{8'hFF, 8'hC0, 8'hC0, 8'hC0, 8'hC0, 8'hFC, 8'h06, 8'h03, 8'h03, 8'h03, 8'h03, 8'h03, 8'hC3, 8'h66, 8'h3C, 8'h00}; //5
        font_rom[6] = '{8'h3C, 8'h66, 8'hC3, 8'hC0, 8'hC0, 8'hC0, 8'hFC, 8'hC6, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'h66, 8'h3C, 8'h00}; //6
        font_rom[7] = '{8'hFF, 8'hC3, 8'h03, 8'h06, 8'h06, 8'h0C, 8'h0C, 8'h18, 8'h18, 8'h30, 8'h30, 8'h60, 8'h60, 8'hC0, 8'hC0, 8'h00}; //7
        font_rom[8] = '{8'h3C, 8'h66, 8'hC3, 8'hC3, 8'hC3, 8'h66, 8'h3C, 8'h66, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'h66, 8'h3C, 8'h00}; //8
        font_rom[9] = '{8'h3C, 8'h66, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'hC3, 8'h63, 8'h3F, 8'h03, 8'h03, 8'h03, 8'hC3, 8'h66, 8'h3C, 8'h00}; //9
		  
		  font_rom[10] = '{8'hFF, 8'hFF, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h00}; //'T'
        font_rom[11] = '{8'hFC, 8'hC6, 8'hC6, 8'hC6, 8'hC6, 8'hFC, 8'hC0, 8'hC0, 8'hC0, 8'hC0, 8'hC0, 8'hC0, 8'hC0, 8'hC0, 8'hC0, 8'h00}; //'P'
        font_rom[12] = '{8'h00, 8'h00, 8'h00, 8'h18, 8'h18, 8'h00, 8'h00, 8'h00, 8'h00, 8'h18, 8'h18, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; //':'
    end

	 // (Масштаб x4)
    logic draw_any;
    logic [3:0] cur_digit;
    logic [2:0] char_x;
    logic [3:0] char_y;
	 logic is_top_score_zone;
    
    // Базовые координаты вывода на экран
    localparam START_X = 11'd40;
    localparam START_Y = 11'd100;
	 localparam TOP_Y   = 11'd180;

    always_comb begin
        draw_any = 1'b0;
        cur_digit  = 4'd0;
        char_x     = 3'd0;
        char_y     = 4'd0;
		  is_top_score_zone = 1'b0;

        //current combo
        if (y >= START_Y && y < START_Y + 11'd64) begin // Зона по Y (высота шрифта 16 пикселей * 4 = 64)
            char_y = (y - START_Y) >> 2;       
            if (x >= START_X && x < START_X + 11'd32) begin // Зона сотен (Ширина 8 пикс * 4 = 32)
                draw_any = 1'b1;
                cur_digit  = combo_hundreds;
                char_x     = 3'd7 - ((x - START_X) >> 2);
            end
           
            else if (x >= START_X + 11'd40 && x < START_X + 11'd72) begin  // Зона десятков (отступ 40 пикс)
                draw_any = 1'b1;
                cur_digit  = combo_tens;
                char_x     = 3'd7 - ((x - (START_X + 11'd40)) >> 2);
            end

            else if (x >= START_X + 11'd80 && x < START_X + 11'd112) begin  // Зона единиц (отступ 80 пикс)
                draw_any = 1'b1;
                cur_digit  = combo_ones;
                char_x     = 3'd7 - ((x - (START_X + 11'd80)) >> 2);
            end
        end
		  else if (y >= TOP_Y && y < TOP_Y + 11'd32) begin
            char_y = (y - TOP_Y) >> 1; // Сдвиг на 1 = деление на 2
            is_top_score_zone = 1'b1;
            
            // Ширина символа x2 = 16 пикселей. Шаг между буквами = 20 пикселей.
            if      (x >= START_X + 0  && x < START_X + 16)  begin draw_any = 1; cur_digit = 4'd10;          char_x = 3'd7 - ((x - (START_X + 0)) >> 1);  end // T
            else if (x >= START_X + 20 && x < START_X + 36)  begin draw_any = 1; cur_digit = 4'd0;           char_x = 3'd7 - ((x - (START_X + 20)) >> 1); end // O 
            else if (x >= START_X + 40 && x < START_X + 56)  begin draw_any = 1; cur_digit = 4'd11;          char_x = 3'd7 - ((x - (START_X + 40)) >> 1); end // P
            else if (x >= START_X + 60 && x < START_X + 76)  begin draw_any = 1; cur_digit = 4'd12;          char_x = 3'd7 - ((x - (START_X + 60)) >> 1); end // :
            // Отступ пробела: 80-100 пустота
            else if (x >= START_X + 100 && x < START_X + 116) begin draw_any = 1; cur_digit = top_hundreds; char_x = 3'd7 - ((x - (START_X + 100)) >> 1); end // Сотни
            else if (x >= START_X + 120 && x < START_X + 136) begin draw_any = 1; cur_digit = top_tens;     char_x = 3'd7 - ((x - (START_X + 120)) >> 1); end // Десятки
            else if (x >= START_X + 140 && x < START_X + 156) begin draw_any = 1; cur_digit = top_ones;     char_x = 3'd7 - ((x - (START_X + 140)) >> 1); end // Единицы
        end
    end

    logic pixel_on;
    assign pixel_on = draw_any ? font_rom[cur_digit][char_y][char_x] : 1'b0;

    always_comb begin
        text_pixel = 2'd0;
        if (pixel_on) begin
            if (is_top_score_zone) 
                text_pixel = 2'd2; //Топ Скор
            else if (combo_ones > 0 || combo_tens > 0 || combo_hundreds > 0) 
                text_pixel = 2'd1; //Комбо 
        end
    end
endmodule