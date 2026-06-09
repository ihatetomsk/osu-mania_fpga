module sprite_combo (
    input  logic        clk,
    input  logic [10:0] x,            
    input  logic [10:0] y,             
    input  logic [3:0]  combo_ones,     
    input  logic [3:0]  combo_tens,    
    input  logic [3:0]  combo_hundreds,  
    input  logic [3:0]  top_ones,       
    input  logic [3:0]  top_tens,        
    input  logic [3:0]  top_hundreds,
    input  logic [1:0]  speed_mode,
    input  logic [1:0]  spawn_mode,
    input  logic [1:0]  mode,            // разрешения экрана
    output logic        speed_pixel,
    output logic        spawn_pixel,   
    output logic        mode_pixel,      
    output logic [1:0]  text_pixel       // 0=пусто, 1=комбо, 2= топ скор
);

    localparam START_X = 11'd40;
    localparam START_Y = 11'd100;
    localparam TOP_Y   = 11'd180;
    localparam Y_SPEED = 11'd230;
    localparam Y_SPAWN = 11'd280;
    localparam Y_MODE  = 11'd330; // Отступ еще 50 пикселей вниз для монитора

    logic [3:0] item_id;
    logic [3:0] item_y;
    logic [2:0] item_x;
    
    logic is_text_zone, is_top_zone, is_speed_icon_zone, is_spawn_icon_zone, is_mode_icon_zone;
    logic draw_speed_bar_next, draw_spawn_bar_next, draw_mode_bar_next;

    always_comb begin
        item_id             = 4'd0;
        item_y              = 4'd0;
        item_x              = 3'd0;
        is_text_zone        = 1'b0;
        is_top_zone         = 1'b0;
        is_speed_icon_zone  = 1'b0;
        is_spawn_icon_zone  = 1'b0;
        is_mode_icon_zone   = 1'b0;
        draw_speed_bar_next = 1'b0;
        draw_spawn_bar_next = 1'b0;
        draw_mode_bar_next  = 1'b0;

        if (y >= START_Y && y < START_Y + 11'd64) begin 
            item_y = (y - START_Y) >> 2;       
            if (x >= START_X && x < START_X + 11'd32) begin 
                is_text_zone = 1'b1; item_id = combo_hundreds; item_x = 3'd7 - ((x - START_X) >> 2);
            end else if (x >= START_X + 11'd40 && x < START_X + 11'd72) begin  
                is_text_zone = 1'b1; item_id = combo_tens; item_x = 3'd7 - ((x - (START_X + 11'd40)) >> 2);
            end else if (x >= START_X + 11'd80 && x < START_X + 11'd112) begin 
                is_text_zone = 1'b1; item_id = combo_ones; item_x = 3'd7 - ((x - (START_X + 11'd80)) >> 2);
            end
        end
        else if (y >= TOP_Y && y < TOP_Y + 11'd32) begin
            item_y = (y - TOP_Y) >> 1; 
            if      (x >= START_X + 0  && x < START_X + 16)  begin is_top_zone = 1; item_id = 4'd10;          item_x = 3'd7 - ((x - (START_X + 0)) >> 1);  end 
            else if (x >= START_X + 20 && x < START_X + 36)  begin is_top_zone = 1; item_id = 4'd0;           item_x = 3'd7 - ((x - (START_X + 20)) >> 1); end  
            else if (x >= START_X + 40 && x < START_X + 56)  begin is_top_zone = 1; item_id = 4'd11;          item_x = 3'd7 - ((x - (START_X + 40)) >> 1); end 
            else if (x >= START_X + 60 && x < START_X + 76)  begin is_top_zone = 1; item_id = 4'd12;          item_x = 3'd7 - ((x - (START_X + 60)) >> 1); end 
            else if (x >= START_X + 100 && x < START_X + 116) begin is_top_zone = 1; item_id = top_hundreds; item_x = 3'd7 - ((x - (START_X + 100)) >> 1); end 
            else if (x >= START_X + 120 && x < START_X + 136) begin is_top_zone = 1; item_id = top_tens;     item_x = 3'd7 - ((x - (START_X + 120)) >> 1); end 
            else if (x >= START_X + 140 && x < START_X + 156) begin is_top_zone = 1; item_id = top_ones;     item_x = 3'd7 - ((x - (START_X + 140)) >> 1); end 
        end
        else if (y >= Y_SPEED && y < Y_SPEED + 11'd32) begin
            if (x >= START_X && x < START_X + 11'd16) begin
                is_speed_icon_zone = 1'b1; item_id = 4'd13;
                item_y = (y - Y_SPEED) >> 1; item_x = 3'd7 - ((x - START_X) >> 1);
            end
            else if (x >= START_X + 11'd24 && x < START_X + 11'd32) draw_speed_bar_next = 1'b1;                  
            else if (x >= START_X + 11'd36 && x < START_X + 11'd44) draw_speed_bar_next = (speed_mode >= 2'd1);  
            else if (x >= START_X + 11'd48 && x < START_X + 11'd56) draw_speed_bar_next = (speed_mode >= 2'd2);  
            else if (x >= START_X + 11'd60 && x < START_X + 11'd68) draw_speed_bar_next = (speed_mode == 2'd3);  
        end
        else if (y >= Y_SPAWN && y < Y_SPAWN + 11'd32) begin
            if (x >= START_X && x < START_X + 11'd16) begin
                is_spawn_icon_zone = 1'b1; item_id = 4'd14;
                item_y = (y - Y_SPAWN) >> 1; item_x = 3'd7 - ((x - START_X) >> 1);
            end
            else if (x >= START_X + 11'd24 && x < START_X + 11'd32) draw_spawn_bar_next = 1'b1;
            else if (x >= START_X + 11'd36 && x < START_X + 11'd44) draw_spawn_bar_next = (spawn_mode >= 2'd1);
            else if (x >= START_X + 11'd48 && x < START_X + 11'd56) draw_spawn_bar_next = (spawn_mode >= 2'd2);
            else if (x >= START_X + 11'd60 && x < START_X + 11'd68) draw_spawn_bar_next = (spawn_mode == 2'd3);
        end
        // Индикатор Разрешения (Mode)
        else if (y >= Y_MODE && y < Y_MODE + 11'd32) begin
            if (x >= START_X && x < START_X + 11'd16) begin
                is_mode_icon_zone = 1'b1; item_id = 4'd15; // Индекс 15 в MIF
                item_y = (y - Y_MODE) >> 1; item_x = 3'd7 - ((x - START_X) >> 1);
            end
            else if (x >= START_X + 11'd24 && x < START_X + 11'd32) draw_mode_bar_next = 1'b1;
            else if (x >= START_X + 11'd36 && x < START_X + 11'd44) draw_mode_bar_next = (mode >= 2'd1);
            else if (x >= START_X + 11'd48 && x < START_X + 11'd56) draw_mode_bar_next = (mode >= 2'd2);
        end
    end

    logic [7:0] rom_addr;
    logic [7:0] rom_data;
    assign rom_addr = {item_id, item_y};

    my_rom rom_inst (
        .address (rom_addr),
        .clock   (clk),
        .q       (rom_data)
    );

    logic [2:0] item_x_reg;
    logic is_text_reg, is_top_reg, is_speed_icon_reg, is_spawn_icon_reg, is_mode_icon_reg;
    logic draw_speed_bar_reg, draw_spawn_bar_reg, draw_mode_bar_reg;

    always_ff @(posedge clk) begin
        item_x_reg         <= item_x;
        is_text_reg        <= is_text_zone;
        is_top_reg         <= is_top_zone;
        is_speed_icon_reg  <= is_speed_icon_zone;
        is_spawn_icon_reg  <= is_spawn_icon_zone;
        is_mode_icon_reg   <= is_mode_icon_zone;     // Задержка флага монитора
        draw_speed_bar_reg <= draw_speed_bar_next;
        draw_spawn_bar_reg <= draw_spawn_bar_next;
        draw_mode_bar_reg  <= draw_mode_bar_next;    // Задержка флага полосок монитора
    end

    logic pixel_on;
    assign pixel_on = rom_data[item_x_reg];

    always_comb begin
        text_pixel  = 2'd0;
        speed_pixel = draw_speed_bar_reg;
        spawn_pixel = draw_spawn_bar_reg;
        mode_pixel  = draw_mode_bar_reg;

        if (pixel_on) begin
            if (is_top_reg) begin
                text_pixel = 2'd2;
            end else if (is_text_reg) begin
                if (combo_ones > 0 || combo_tens > 0 || combo_hundreds > 0) text_pixel = 2'd1;
            end else if (is_speed_icon_reg) begin
                speed_pixel = 1'b1;
            end else if (is_spawn_icon_reg) begin
                spawn_pixel = 1'b1;
            end else if (is_mode_icon_reg) begin
                mode_pixel = 1'b1; // Отрисовка иконки монитора
            end
        end
    end

endmodule