module pattern_gen (
    input  logic clk,       // clk from pll
    input  logic rst,       
    input  logic [1:0] mode, // ������� ����� ����������
	 input  logic [1:0] speed_mode,
	 input  logic [1:0] spawn_mode,
    input  logic [10:0] x,   // current pos X (�� vga_generator)
    input  logic [10:0] y,   // current pos Y (�� vga_generator)
    input  logic de,        // Data Enable
    input  logic[3:0] keys,
    output logic [7:0] r,   
    output logic [7:0] g,   
    output logic [7:0] b    
);

    // random number
    logic [31:0] lfsr;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) 
            lfsr <= 32'hACE1; // Стартовое значение (любое, кроме нуля)
        else 
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]} ^ {28'b0, keys};
    end


    // positions
    logic frame_tick;
    // generate frame tick at the end of each frame (when we are at the last pixel)
	 
    // ------------------------------------------------------------
    // �����-��������� ��������� ��������� � �������� ����
    // ------------------------------------------------------------
    logic [10:0] h_res, v_res;
    logic [10:0] game_left, game_right;
    logic [10:0] BLOCK_WIDTH;
    logic [10:0] BLOCK_HEIGHT;
    logic [10:0] HIT_Y_START;
    logic [10:0] HIT_Y_END;
    logic [10:0] REC_Y_START;
    logic [10:0] REC_Y_END;
    logic [10:0] block_speed;
    logic [10:0] bx [0:3];
	logic [10:0] base_speed;
	logic [5:0]  spawn_interval;
	 
	 logic [3:0] lane_hit_reg; // Регистр задержки попадания для счетчиков
	 
    always_comb begin
		  
        case (mode)
            2'b00: begin // 640x480 @ 60Hz
                h_res       = 11'd640;  v_res       = 11'd480;
                game_left   = 11'd215;   game_right  = 11'd426;
                BLOCK_WIDTH = 11'd52;    BLOCK_HEIGHT= 11'd13;
                HIT_Y_START = 11'd400;   HIT_Y_END   = 11'd419;
                REC_Y_START = 11'd420;   REC_Y_END   = 11'd479;
                base_speed  = 11'd2;
					 block_speed = base_speed + {9'd0, speed_mode}; 
                bx[0] = 11'd215; bx[1] = 11'd268; bx[2] = 11'd321; bx[3] = 11'd374;
            end
            2'b01: begin // 800x600 @ 60Hz
                h_res       = 11'd800;  v_res       = 11'd600;
                game_left   = 11'd280;   game_right  = 11'd523;
                BLOCK_WIDTH = 11'd60;    BLOCK_HEIGHT= 11'd16;
                HIT_Y_START = 11'd500;   HIT_Y_END   = 11'd525;
                REC_Y_START = 11'd526;   REC_Y_END   = 11'd599;
                base_speed  = 11'd2;
					 block_speed = base_speed + ({9'd0, speed_mode} << 1);
                bx[0] = 11'd280; bx[1] = 11'd341; bx[2] = 11'd402; bx[3] = 11'd463;
            end
            2'b10: begin // 1024x768 @ 60Hz
                h_res       = 11'd1024; v_res       = 11'd768;
                game_left   = 11'd362;   game_right  = 11'd665;
                BLOCK_WIDTH = 11'd75;    BLOCK_HEIGHT= 11'd21;
                HIT_Y_START = 11'd650;   HIT_Y_END   = 11'd680;
                REC_Y_START = 11'd681;   REC_Y_END   = 11'd767;
                base_speed  = 11'd2;
					 block_speed = base_speed + ({9'd0, speed_mode} << 1)+ {9'd0, speed_mode};
                bx[0] = 11'd362; bx[1] = 11'd438; bx[2] = 11'd514; bx[3] = 11'd590;
            end
            default: begin // ������ 640x480
                h_res       = 11'd640;  v_res       = 11'd480;
                game_left   = 11'd215;   game_right  = 11'd426;
                BLOCK_WIDTH = 11'd52;    BLOCK_HEIGHT= 11'd13;
                HIT_Y_START = 11'd400;   HIT_Y_END   = 11'd419;
                REC_Y_START = 11'd420;   REC_Y_END   = 11'd479;
                base_speed  = 11'd2;
					 block_speed = base_speed + {9'd0, speed_mode};
                bx[0] = 11'd215; bx[1] = 11'd268; bx[2] = 11'd321; bx[3] = 11'd374;
            end
        endcase
    end
	 
	 always_comb begin
        case (spawn_mode)
            2'b00:   spawn_interval = 6'd50; // Редкие ноты (Супер-изи)
            2'b01:   spawn_interval = 6'd30; // Стандартный режим
            2'b10:   spawn_interval = 6'd18; // Плотный поток (Сложно)
            2'b11:   spawn_interval = 6'd10; // "Стена" из блоков (Абсолютное безумие!)
            default: spawn_interval = 6'd30;
        endcase
    end

    assign frame_tick = (x == h_res - 11'd1 && y == v_res - 11'd1);
	 
	 
	localparam MAX_BLOCKS   = 13; //max quantity of blocks on screen
	logic [10:0] block_y[0:MAX_BLOCKS-1]; // height of every block
    logic [1:0] block_lane[0:MAX_BLOCKS-1]; // in what column
    logic       block_visible [0:MAX_BLOCKS-1]; // 1 - block in process to catch, 0 - caught/free
	 
    logic [5:0] spawn_timer;   // timer for block generation
    logic [4:0] flash [0:3];   // 4 timers for flash in each column
    logic [3:0] keys_prev;     
	 
	 //logic to find block with visible =0 to regenerate
	 logic[3:0] free_idx;
    logic      has_free;
    always_comb begin
        free_idx = 4'd0;
        has_free = 1'b0;
        for (int i = MAX_BLOCKS-1; i >= 0; i--) begin
            if (!block_visible[i]) begin
                free_idx = i[3:0];
                has_free = 1'b1;
            end
        end
    end


	logic [3:0] keys_pulse;
    logic [3:0] keys_flipped;

    assign keys_flipped[0] = keys[3]; // ������� ����� ��� (������ BTN[3]) -> 0-� ��� ������
    assign keys_flipped[1] = keys[2]; // ����� ��� -> 1-� ���
    assign keys_flipped[2] = keys[1]; // ������ ��� -> 2-� ���
    assign keys_flipped[3] = keys[0]; // ������� ������ ��� (������ BTN[0]) -> 3-� ��� ������

	logic [3:0] combo_ones;
    logic [3:0] combo_tens;
    logic [3:0] combo_hundreds;
	logic [3:0] top_ones, top_tens, top_hundreds;
	 
	logic is_new_record;
    assign is_new_record = (combo_ones == top_ones) && (combo_tens == top_tens) && (combo_hundreds == top_hundreds);
	 
	assign keys_pulse = keys & ~keys_prev;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            combo_ones     <= 4'd0;
            combo_tens     <= 4'd0;
            combo_hundreds <= 4'd0;
            top_ones       <= 4'd0;
            top_tens       <= 4'd0;
            top_hundreds   <= 4'd0;
            for (int i=0; i < MAX_BLOCKS; i++) begin
                block_visible[i] <= 1'b0;
                block_y[i]       <= 11'd0;
                block_lane[i]    <= 2'd0;
            end
            for (int i=0; i < 4; i++) flash[i] <= 5'd0;
            spawn_timer <= 0;
            keys_prev   <= 4'd0;
        end else begin
            keys_prev <= keys;
            if (frame_tick) begin
                for(int j=0; j < 4; j++) begin
                    if (flash[j] > 0) flash[j] <= flash[j] - 5'd1;
                end
                spawn_timer <= spawn_timer + 6'd1; //every 2 sec
                if (spawn_timer >= spawn_interval) begin
                    spawn_timer <= 0;
                    if (has_free) begin
                        block_visible[free_idx] <= 1'b1;
                        block_y[free_idx]       <= 11'd0;
                        block_lane[free_idx]    <= lfsr[1:0]; // random column for new block
                    end
                    
                    if (lfsr[8] && lfsr[7] && lfsr[6] && has_free) begin //условие для генерации двух нот одновременно(шанс 12%)
                        
                        logic [3:0] second_free;
                        logic found_second;
                        
                        // Инициализируем переменные поиска по умолчанию
                        second_free  = 4'd0;
                        found_second = 1'b0;
                        
                        // Ищем вторую свободную ячейку в массиве
                        for (int i = 0; i < MAX_BLOCKS; i++) begin
                            // Если ячейка свободна И это не та ячейка, которую мы заняли под первую ноту
                            if (!block_visible[i] && i[3:0] != free_idx) begin
                                second_free  = i[3:0];
                                found_second = 1'b1;
                            end
                        end
                        
                        // Если нашли второе свободное место — спавним второй блок
                        if (found_second) begin
                            block_visible[second_free] <= 1'b1;
                            block_y[second_free]       <= 11'd0;
                            // Сдвигаем дорожку второй ноты на соседнюю с помощью операции ^ 2'b01
                            block_lane[second_free]    <= (lfsr[10:9] == lfsr[1:0]) ? (lfsr[1:0] ^ 2'b01) : lfsr[10:9]; 
                        end
                    end
                end
                    
                for (int i=0; i < MAX_BLOCKS; i++) begin
                    if (block_visible[i]) begin
                        if (block_y[i] + BLOCK_HEIGHT >= v_res) begin
                            block_visible[i] <= 1'b0; // block is out of screen
                            combo_ones <= 4'd0;
                            combo_tens <= 4'd0;
                            combo_hundreds <= 4'd0;
                        end else 
                            block_y[i] <= block_y[i] + block_speed;
                    end
                end
            end
            
            lane_hit_reg <= 4'b0000;    
            //истребление блоков
            for (int i=0; i < MAX_BLOCKS; i++) begin
                if (block_visible[i]) begin
                    // if we have press in current lane and block in hit zone by Y - catch block
                    if (keys_pulse[block_lane[i]] && 
                       (block_y[i] + BLOCK_HEIGHT >= HIT_Y_START) && 
                       (block_y[i] <= HIT_Y_END)) begin
                        
                        block_visible[i]     <= 1'b0;  // hide block (caught)
                        lane_hit_reg[block_lane[i]] <= 1'b1; //save in what colomn we caught
                    end
                end
            end 
            //запуск анимации и расчет комбо на следующем такте
            for (int j = 0; j < 4; j++) begin   
                if (lane_hit_reg[j]) begin  
                    flash[j] <= 5'd31;      
                        
                    if (combo_ones == 9) begin
                        combo_ones <= 0;
                        if (is_new_record) top_ones <= 0; 

                        if (combo_tens == 9) begin
                            combo_tens <= 0;
                            if (is_new_record) top_tens <= 0;
                            
                            if (combo_hundreds < 9) begin
                                combo_hundreds <= combo_hundreds + 1;
                                if (is_new_record) top_hundreds <= top_hundreds + 1;
                            end
                        end else begin
                            combo_tens <= combo_tens + 1;
                            if (is_new_record) top_tens <= top_tens + 1;
                        end
                    end else begin
                        combo_ones <= combo_ones + 1;
                        if (is_new_record) top_ones <= top_ones + 1; // Если идем на рекорд, обновляем
                    end
                end
            end
        end
    end

////////////////////////////////////////////////////////////

    //user blocks in bottom
    assign in_rec_y = (y >= REC_Y_START) && (y <= REC_Y_END);
	 
    logic [3:0] in_rec_x; // understand in what column we are
    assign in_rec_x[0] = (x >= bx[0]) && (x < bx[0] + BLOCK_WIDTH);
    assign in_rec_x[1] = (x >= bx[1]) && (x < bx[1] + BLOCK_WIDTH);
    assign in_rec_x[2] = (x >= bx[2]) && (x < bx[2] + BLOCK_WIDTH);
    assign in_rec_x[3] = (x >= bx[3]) && (x < bx[3] + BLOCK_WIDTH);
	 
    logic fill_rec_0, fill_rec_1, fill_rec_2, fill_rec_3;
    assign fill_rec_0 = in_rec_y && in_rec_x[0];
    assign fill_rec_1 = in_rec_y && in_rec_x[1];
    assign fill_rec_2 = in_rec_y && in_rec_x[2];
    assign fill_rec_3 = in_rec_y && in_rec_x[3];
	 
////////////////////////////////////////////////////////////
    logic [1:0] cur_col;
    logic is_in_col;
    always_comb begin
        cur_col = 2'd0;
        is_in_col = 1'b0;
        if      (in_rec_x[0]) begin cur_col = 2'd0; is_in_col = 1'b1; end
        else if (in_rec_x[1]) begin cur_col = 2'd1; is_in_col = 1'b1; end
        else if (in_rec_x[2]) begin cur_col = 2'd2; is_in_col = 1'b1; end
        else if (in_rec_x[3]) begin cur_col = 2'd3; is_in_col = 1'b1; end
    end


    logic [9:0] base_val;
    logic [10:0] dist_y;
    logic signed [11:0] intensity;
	 logic [7:0] bloom_out;
    always_comb begin
        bloom_out = 8'h00;
        base_val  = 10'd0;
        dist_y    = 11'd0;
        intensity = 12'd0;
        
        // ���� ������� � �������, ��� ���� ������� � �� � ������ ���� �� Y
        if (is_in_col && flash[cur_col] > 0 && y <= HIT_Y_END) begin
            
            // ��������� �� 8 �������� ������� ����� �� 3 (<< 3) - ��� �������� ���������
            base_val = {5'b0, flash[cur_col]} << 3; 
            
            // ��������� �� Y
            dist_y = HIT_Y_END - y;
            
            // ��������� �� 2 �������� ������� ����� �� 1 (<< 1)
            // intensity = base_val - (dist_y * 2)
            intensity = $signed({2'b0, base_val}) - $signed({1'b0, dist_y, 1'b0});
            
            if (intensity > 0) begin
                if (intensity > 255) bloom_out = 8'hFF;
                else bloom_out = intensity[7:0];
            end
        end
    end

////////////////////////////////////////////////////////////
    logic draw_block_any;
    always_comb begin
        draw_block_any = 1'b0;
        for (int i = 0; i < MAX_BLOCKS; i++) begin
            if (block_visible[i]) begin
                if (in_rec_x[block_lane[i]]) begin
                    if (y >= block_y[i] && y < block_y[i] + BLOCK_HEIGHT) begin
                        draw_block_any = 1'b1;
                    end
                end
            end
        end
    end

////////////////////////////////////////////////////////////
//combo draw
    logic [1:0] text_pixel_type;

    sprite_combo text_engine (
        .x              (x),
        .y              (y),
        .combo_ones     (combo_ones),
        .combo_tens     (combo_tens),
        .combo_hundreds (combo_hundreds),
        .top_ones       (top_ones),         
        .top_tens       (top_tens),
        .top_hundreds   (top_hundreds),
        .text_pixel     (text_pixel_type) 
    );

////////////////////////////////////////////////////////////
    
    //draw logic
    logic in_hit_zone_y;
    logic draw_line_left;
    logic draw_line_right;
    logic draw_zone;
    
    logic [23:0] rgb_out; 
                       
    // border lines
    assign draw_line_left  = (x == game_left - 11'd2) || (x == game_left - 11'd1);
    assign draw_line_right = (x == game_right) || (x == game_right + 11'd1);
    
    // main game zone
    assign draw_zone = (x >= game_left) && (x < game_right);
	 
	 assign in_hit_zone_y   = (y >= HIT_Y_START) && (y <= HIT_Y_END);

    logic [23:0] next_rgb_out; 
	 

	 
    // main draw process
    always_comb begin
        if (!de) begin
            next_rgb_out = 24'h000000;    
        end else begin
		  
		      if (draw_line_left || draw_line_right)
                next_rgb_out  = 24'hFFFFFF; // white line of borders
					 
				else if (bloom_out > 200) begin 
                //in center of flash make white color
                next_rgb_out  = 24'hFFFFFF;
            end

            else if (draw_block_any)
                next_rgb_out  = 24'hFF3333; //blocks
					 
				else if (text_pixel_type != 2'd0)
                next_rgb_out  = 24'h00FFFF;
					 
				else begin
                logic [7:0] base_r, base_g, base_b;
                logic [8:0] sum_r, sum_g, sum_b;
                
                // base colors
                if (fill_rec_0) {base_r, base_g, base_b} = keys[0] ? 24'hFFFFFF : 24'hFF8800;
                else if (fill_rec_1) {base_r, base_g, base_b} = keys[1] ? 24'hFFFFFF : 24'hFF8800;
                else if (fill_rec_2) {base_r, base_g, base_b} = keys[2] ? 24'hFFFFFF : 24'hFF8800;
                else if (fill_rec_3) {base_r, base_g, base_b} = keys[3] ? 24'hFFFFFF : 24'hFF8800;
                else if (in_hit_zone_y && draw_zone) {base_r, base_g, base_b} = 24'h445566;
                else if (draw_zone) {base_r, base_g, base_b} = 24'h222222;
                else {base_r, base_g, base_b} = 24'h000000;

                // add effect bloom
                sum_r = base_r + bloom_out;
                sum_g = base_g + bloom_out;
                sum_b = base_b + bloom_out;    

                next_rgb_out[23:16] = sum_r[8] ? 8'hFF : sum_r[7:0];
                next_rgb_out[15:8]  = sum_g[8] ? 8'hFF : sum_g[7:0];
                next_rgb_out[7:0]   = sum_b[8] ? 8'hFF : sum_b[7:0];
                
            end
        end
    end

    logic [23:0] rgb_out_reg;
    always_ff @(posedge clk) begin
        if (rst) rgb_out_reg <= 24'h000000;
        else     rgb_out_reg <= next_rgb_out;
    end
    // decompose 24-bit color to RGB channels
    assign r = rgb_out_reg[23:16];
    assign g = rgb_out_reg[15:8];
    assign b = rgb_out_reg[7:0];

endmodule