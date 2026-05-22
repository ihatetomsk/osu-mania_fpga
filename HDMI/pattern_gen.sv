module pattern_gen (
    input  logic clk,       // clk from pll
    input  logic rst,       
    input  logic [1:0] mode, // Текущий режим разрешения
    input  logic [10:0] x,   // current pos X (от vga_generator)
    input  logic [10:0] y,   // current pos Y (от vga_generator)
    input  logic de,        // Data Enable
    input  logic[3:0] keys,
    output logic [7:0] r,   
    output logic [7:0] g,   
    output logic [7:0] b    
);

    // random number
    logic [7:0] lfsr;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) 
            lfsr <= 8'hAA; // start value
        else 
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]}; 
    end


    // positions
    logic frame_tick;
    // generate frame tick at the end of each frame (when we are at the last pixel)
	 
    // ------------------------------------------------------------
    // Режим-зависимые параметры развертки и игрового поля
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

    always_comb begin
        case (mode)
            2'b00: begin // 640x480 @ 60Hz
                h_res       = 11'd640;  v_res       = 11'd480;
                game_left   = 11'd215;   game_right  = 11'd426;
                BLOCK_WIDTH = 11'd52;    BLOCK_HEIGHT= 11'd13;
                HIT_Y_START = 11'd400;   HIT_Y_END   = 11'd419;
                REC_Y_START = 11'd420;   REC_Y_END   = 11'd479;
                block_speed = 11'd3;
                bx[0] = 11'd215; bx[1] = 11'd268; bx[2] = 11'd321; bx[3] = 11'd374;
            end
            2'b01: begin // 800x600 @ 60Hz
                h_res       = 11'd800;  v_res       = 11'd600;
                game_left   = 11'd280;   game_right  = 11'd520;
                BLOCK_WIDTH = 11'd60;    BLOCK_HEIGHT= 11'd16;
                HIT_Y_START = 11'd500;   HIT_Y_END   = 11'd525;
                REC_Y_START = 11'd526;   REC_Y_END   = 11'd599;
                block_speed = 11'd4;
                bx[0] = 11'd280; bx[1] = 11'd341; bx[2] = 11'd402; bx[3] = 11'd463;
            end
            2'b10: begin // 1024x768 @ 60Hz
                h_res       = 11'd1024; v_res       = 11'd768;
                game_left   = 11'd362;   game_right  = 11'd662;
                BLOCK_WIDTH = 11'd75;    BLOCK_HEIGHT= 11'd21;
                HIT_Y_START = 11'd650;   HIT_Y_END   = 11'd680;
                REC_Y_START = 11'd681;   REC_Y_END   = 11'd767;
                block_speed = 11'd5;
                bx[0] = 11'd362; bx[1] = 11'd438; bx[2] = 11'd514; bx[3] = 11'd590;
            end
            default: begin // Дефолт 640x480
                h_res       = 11'd640;  v_res       = 11'd480;
                game_left   = 11'd215;   game_right  = 11'd426;
                BLOCK_WIDTH = 11'd52;    BLOCK_HEIGHT= 11'd13;
                HIT_Y_START = 11'd400;   HIT_Y_END   = 11'd419;
                REC_Y_START = 11'd420;   REC_Y_END   = 11'd479;
                block_speed = 11'd3;
                bx[0] = 11'd215; bx[1] = 11'd268; bx[2] = 11'd321; bx[3] = 11'd374;
            end
        endcase
    end

    assign frame_tick = (x == h_res - 11'd1 && y == v_res - 11'd1);
	 
	 
	localparam MAX_BLOCKS   = 10; //max quantity of blocks on screen
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

    assign keys_flipped[0] = keys[3]; // крайний левый ряд (кнопка BTN[3]) -> 0-й ряд игрока
    assign keys_flipped[1] = keys[2]; // левый ряд -> 1-й ряд
    assign keys_flipped[2] = keys[1]; // правый ряд -> 2-й ряд
    assign keys_flipped[3] = keys[0]; // крайний правый ряд (кнопка BTN[0]) -> 3-й ряд игрока

	assign keys_pulse = keys & ~keys_prev;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
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
                if (spawn_timer >= 6'd30) begin
                    spawn_timer <= 0;
                    if (has_free) begin
                        block_visible[free_idx] <= 1'b1;
                        block_y[free_idx]       <= 11'd0;
                        block_lane[free_idx]    <= lfsr[1:0]; // random column for new block
                    end
                end
                    
                for (int i=0; i < MAX_BLOCKS; i++) begin
                    if (block_visible[i]) begin
                        if (block_y[i] + BLOCK_HEIGHT >= v_res) 
                            block_visible[i] <= 1'b0; // block is out of screen
                        else 
                            block_y[i] <= block_y[i] + block_speed;
                    end
                end
            end
					 
			for (int i=0; i < MAX_BLOCKS; i++) begin
                if (block_visible[i]) begin
                    // if we have press in current lane and block in hit zone by Y - catch block
                    if (keys_pulse[block_lane[i]] && 
                       (block_y[i] + BLOCK_HEIGHT >= HIT_Y_START) && 
                       (block_y[i] <= HIT_Y_END)) begin
                        
                        block_visible[i]     <= 1'b0;  // hide block (caught)
                        flash[block_lane[i]] <= 5'd31; 
                    end
                end
            end
        end
    end
	 
	 logic [7:0] bloom_out;
	 always_comb begin
        bloom_out = 8'h00;
        
        for (int i = 0; i < 4; i++) begin
            //if flash active and we are in rec zone
            if (flash[i] > 0 && in_rec_x[i]) begin
                
                // check if we are in hit zone by Y
                if (y <= HIT_Y_END) begin
                    int intensity;
                    int base_val;
                    int dist_y;
                    
                    // base value of bloom effect depends on flash timer, when flash = 31 -> base_val = 248, when flash = 1 -> base_val = 8
                    base_val = int'(flash[i]) * 8;
                    
                    // distance from current pixel to hit zone, when we are in hit zone -> dist_y = 0
                    dist_y = int'(HIT_Y_END) - int'(y);
                    
                    // intensity of bloom effect decreases as we move away from hit zone
                    intensity = base_val - (dist_y * 2); 
                    
                    if (intensity > 0) begin
                        // add bloom effect to current pixel
                        if (int'(bloom_out) + intensity > 255) bloom_out = 8'hFF;
                        else bloom_out = bloom_out + intensity[7:0];
                    end
                end
            end
        end
    end


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

	logic draw_block_any;
    always_comb begin
        draw_block_any = 1'b0;
        for (int i = 0; i < MAX_BLOCKS; i++) begin
            if (block_visible[i]) begin
                if (x >= bx[block_lane[i]] && x < bx[block_lane[i]] + BLOCK_WIDTH &&
                    y >= block_y[i] && y < block_y[i] + BLOCK_HEIGHT) begin
                    draw_block_any = 1'b1;
                end
            end
        end
    end
	 
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
	 
	 
    // main draw process
    always_comb begin
        if (!de) begin
            rgb_out = 24'h000000;     
        end else begin
		  
		      if (draw_line_left || draw_line_right)
                rgb_out = 24'hFFFFFF; // white line of borders
					 
				else if (bloom_out > 200) begin 
                //in center of flash make white color
                rgb_out = 24'hFFFFFF;
            end

            else if (draw_block_any)
                rgb_out = 24'hFF3333; //blocks
					 
				else begin
                logic [7:0] base_r, base_g, base_b;
                
                // base colors
                if (fill_rec_0) {base_r, base_g, base_b} = keys_flipped[0] ? 24'hFFFFFF : 24'hFF8800;
                else if (fill_rec_1) {base_r, base_g, base_b} = keys_flipped[1] ? 24'hFFFFFF : 24'hFF8800;
                else if (fill_rec_2) {base_r, base_g, base_b} = keys_flipped[2] ? 24'hFFFFFF : 24'hFF8800;
                else if (fill_rec_3) {base_r, base_g, base_b} = keys_flipped[3] ? 24'hFFFFFF : 24'hFF8800;
                else if (in_hit_zone_y && draw_zone) {base_r, base_g, base_b} = 24'h445566;
                else if (draw_zone) {base_r, base_g, base_b} = 24'h222222;
                else {base_r, base_g, base_b} = 24'h000000;


                // add effect bloom
                rgb_out[23:16] = (base_r + bloom_out > 255) ? 8'hFF : base_r + bloom_out;
                rgb_out[15:8]  = (base_g + bloom_out > 255) ? 8'hFF : base_g + bloom_out;
                rgb_out[7:0]   = (base_b + bloom_out > 255) ? 8'hFF : base_b + bloom_out;
            end
        end
    end
    // decompose 24-bit color to RGB channels
    assign r = rgb_out[23:16];
    assign g = rgb_out[15:8];
    assign b = rgb_out[7:0];

endmodule