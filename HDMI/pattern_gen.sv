module pattern_gen (
    input  logic clk,       // Тактовая частота 25 МГц (от PLL)
    input  logic rst,       // Сигнал сброса (от кнопки)
    input  logic [9:0] x,   // Текущая координата X (от vga_generator)
    input  logic [9:0] y,   // Текущая координата Y (от vga_generator)
    input  logic de,        // Флаг активного видео (Data Enable)
	 input  logic[3:0] keys,
    output logic [7:0] r,   // Выход цвета Red
    output logic [7:0] g,   // Выход цвета Green
    output logic [7:0] b    // Выход цвета Blue
);

    // ==========================================
    // random number
    // ==========================================
    logic [7:0] lfsr;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) 
            lfsr <= 8'hAA; // Стартовое значение (не должно быть нулем!)
        else 
            // Сдвиг влево и XOR для обратной связи
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]}; 
    end

    // ==========================================
    // positions
    // ==========================================
    logic frame_tick;
    // Генерируем короткий импульс 1 раз за кадр (когда луч уходит в невидимую зону)
    assign frame_tick = (x == 10'd639 && y == 10'd479);

//    logic [9:0] block_x;
//    logic [9:0] block_y;
	 
	 
	 localparam BLOCK_WIDTH  = 10'd52; 
    localparam BLOCK_HEIGHT = 10'd13; 
	 
	 	 //capture zone
	 localparam HIT_Y_START = 10'd400; 
    localparam HIT_Y_END   = 10'd419; 
	 
	 localparam MAX_BLOCKS   = 10; //max quantity of blocks on screen
	 logic [9:0] block_y[0:MAX_BLOCKS-1]; // hight of every block
    logic [1:0] block_lane[0:MAX_BLOCKS-1]; // in what colomn
    logic       block_visible [0:MAX_BLOCKS-1]; // 1 - block in procees to catch, 0 - caught/free
	 
    logic [5:0] spawn_timer;   // timer for block generate
    logic [4:0] flash [0:3];   // 4 timers for flash in each coloumn
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
	 assign keys_pulse = keys & ~keys_prev;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
				for (int i=0; i<MAX_BLOCKS; i++) begin
                block_visible[i] <= 1'b0;
                block_y[i]       <= 10'd0;
                block_lane[i]    <= 2'd0;
            end
				for (int i=0; i<4; i++) flash[i] <= 5'd0;
            spawn_timer <= 0;
            keys_prev   <= 4'd0;
            //block_y <= 10'd0;
            //block_x <= 10'd221; // По умолчанию ставим в крайнюю левую полосу
        end else begin
            // Если блок улетел за нижний край экрана
				keys_prev <= keys;
				
				if (frame_tick) begin
					 for(int j=0; j<4; j++) begin
                    if (flash[j] > 0) flash[j] <= flash[j] - 5'd1;
                end
					 spawn_timer <= spawn_timer + 6'd1; //every 2 sec
					 if (spawn_timer >= 6'd30) begin
                    spawn_timer <= 0;
                    if (has_free) begin
                        block_visible[free_idx] <= 1'b1;
                        block_y[free_idx]       <= 10'd0;
                        block_lane[free_idx]    <= lfsr[1:0]; // Случайная колонка
                    end
                end
					 
					 for (int i=0; i<MAX_BLOCKS; i++) begin
                    if (block_visible[i]) begin
                        if (block_y[i] >= 10'd480) 
                            block_visible[i] <= 1'b0; // Блок улетел за экран (Miss)
                        else 
                            block_y[i] <= block_y[i] + 10'd3;
                    end
                end
				end
					 
				for (int i=0; i<MAX_BLOCKS; i++) begin
                if (block_visible[i]) begin
                    // Если нажата кнопка в колонке блока, и блок внутри зоны захвата
                    if (keys_pulse[block_lane[i]] && 
                       (block_y[i] + BLOCK_HEIGHT >= HIT_Y_START) && 
                       (block_y[i] <= HIT_Y_END)) begin
                        
                        block_visible[i]     <= 1'b0;  // Прячем пойманный блок
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
            // Если в этой колонке активна вспышка и текущий X в этой колонке
            if (flash[i] > 0 && in_rec_x[i]) begin
                
                // Проверяем, что мы выше нижней границы хит-зоны
                if (y <= HIT_Y_END) begin
                    int intensity;
                    int base_val;
                    int dist_y;
                    
                    // 1. Базовая яркость от таймера (от 0 до 248)
                    base_val = int'(flash[i]) * 8;
                    
                    // 2. Расстояние вверх от хит-зоны
                    // В самой хит-зоне (y около 410) dist_y будет около 0.
                    // На самом верху экрана (y = 0) dist_y будет около 410.
                    dist_y = int'(HIT_Y_END) - int'(y);
                    
                    // 3. Формула столба:
                    // Берем базовую яркость и вычитаем дистанцию по Y.
                    // Коэффициент перед dist_y (например, 1 или 2) определяет высоту столба.
                    // Если (dist_y * 1) -> столб высокий (на весь экран).
                    // Если (dist_y * 3) -> столб короткий (быстро тускнеет вверх).
                    intensity = base_val - (dist_y * 2); 
                    
                    if (intensity > 0) begin
                        // Сложение с насыщением
                        if (int'(bloom_out) + intensity > 255) bloom_out = 8'hFF;
                        else bloom_out = bloom_out + intensity[7:0];
                    end
                end
            end
        end
    end
//	 always_comb begin
//        bloom_out = 8'h00;
//        
//        for (int i = 0; i < 4; i++) begin
//            if (flash[i] > 0) begin
//					 int centerX, centerY;
//                int dx, dy, distance, intensity; 
//                // Центр колонки по X
//                centerX = 215 + (i * 53) + 26;
//                // Центр хит-зоны по Y
//                centerY = (HIT_Y_START + HIT_Y_END) / 2;
//                
//                // Считаем примерное расстояние (Манхэттенское расстояние для экономии ресурсов)
//                // dist = |dx| + |dy|
//                dx = (x > centerX) ? (x - centerX) : (centerX - x);
//                dy = (y > centerY) ? (y - centerY) : (centerY - y);
//					 
//                distance  = dx + dy;
//
//                // Вычисляем яркость в этой точке:
//                // Базовая яркость зависит от таймера (flash * 8)
//                // И уменьшается с расстоянием (dist * 2)
//                intensity = (flash[i] * 10) - (distance  * 4);
//                
//                if (intensity > 0) begin
//                    // Если интенсивность положительная, добавляем её к результату
//                    // Используем сложение с насыщением (чтобы не превысить 255)
//                    if (bloom_out + intensity > 255) bloom_out = 8'hFF;
//                    else bloom_out = bloom_out + intensity[7:0];
//                end
//            end
//        end
//    end

    // ==========================================
    // 3. ЛОГИКА ОТРИСОВКИ СЛОЕВ (ГРАФИКА)
    // ==========================================
    logic in_hit_zone_y;
    logic draw_line_left;
    logic draw_line_right;
    logic draw_zone;
    
    logic [23:0] rgb_out; // Внутренний провод для сборки 24-битного цвета
                       
    // Флаг 2: Левая белая разделительная граница (ширина 2 пикселя)
    assign draw_line_left  = (x == 10'd213) || (x == 10'd214);
    
    // Флаг 3: Правая белая разделительная граница (ширина 2 пикселя)
    assign draw_line_right = (x == 10'd426) || (x == 10'd427);
    
    // Флаг 4: Игровой стакан (пространство между линиями)
    assign draw_zone = (x >= 10'd215) && (x < 10'd426);
	 
	 assign in_hit_zone_y   = (y >= HIT_Y_START) && (y <= HIT_Y_END);

	 logic draw_block_any;
    always_comb begin
        draw_block_any = 1'b0;
        for (int i = 0; i < MAX_BLOCKS; i++) begin
            if (block_visible[i]) begin
                logic [9:0] bx;
                case (block_lane[i])
                    2'd0: bx = 10'd215;
                    2'd1: bx = 10'd268;
                    2'd2: bx = 10'd321;
                    2'd3: bx = 10'd374;
                endcase
                
                if (x >= bx && x < bx + BLOCK_WIDTH &&
                    y >= block_y[i] && y < block_y[i] + BLOCK_HEIGHT) begin
                    draw_block_any = 1'b1;
                end
            end
        end
    end
	 
	 //user blocks in bottom
	 localparam REC_Y_START = 10'd420; 
    localparam REC_Y_END   = 10'd479; 
	 logic in_rec_y;
    assign in_rec_y = (y >= REC_Y_START) && (y <= REC_Y_END);
	 
    logic [3:0] in_rec_x; // Определяем, в какой колонке находится пиксель
    assign in_rec_x[0] = (x >= 10'd215) && (x <= 10'd266);
    assign in_rec_x[1] = (x >= 10'd268) && (x <= 10'd319);
    assign in_rec_x[2] = (x >= 10'd321) && (x <= 10'd372);
    assign in_rec_x[3] = (x >= 10'd374) && (x <= 10'd425);
	 
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
                // В самом центре вспышка почти белая
                rgb_out = 24'hFFFFFF;
            end

            else if (draw_block_any)
                rgb_out = 24'hFF3333; //blocks
					 
				else begin
                logic [7:0] base_r, base_g, base_b;
                
                // Определяем базовый цвет пикселя (кнопки, хит-зона или фон)
                if (fill_rec_0) {base_r, base_g, base_b} = keys[0] ? 24'hFFFFFF : 24'hFF8800;
                else if (fill_rec_1) {base_r, base_g, base_b} = keys[1] ? 24'hFFFFFF : 24'hFF8800;
                else if (fill_rec_2) {base_r, base_g, base_b} = keys[2] ? 24'hFFFFFF : 24'hFF8800;
                else if (fill_rec_3) {base_r, base_g, base_b} = keys[3] ? 24'hFFFFFF : 24'hFF8800;
                else if (in_hit_zone_y && draw_zone) {base_r, base_g, base_b} = 24'h445566;
                else if (draw_zone) {base_r, base_g, base_b} = 24'h222222;
                else {base_r, base_g, base_b} = 24'h000000;

                // ДОБАВЛЯЕМ СВЕЧЕНИЕ К БАЗОВОМУ ЦВЕТУ
                // Это создает эффект "освещения" фоновых объектов вспышкой
                rgb_out[23:16] = (base_r + bloom_out > 255) ? 8'hFF : base_r + bloom_out;
                rgb_out[15:8]  = (base_g + bloom_out > 255) ? 8'hFF : base_g + bloom_out;
                rgb_out[7:0]   = (base_b + bloom_out > 255) ? 8'hFF : base_b + bloom_out;
            end
					 
				//hit zone
//				else if (in_hit_zone_y && in_rec_x[0] && flash[0] > 0) rgb_out = 24'h33FF33;
//            else if (in_hit_zone_y && in_rec_x[1] && flash[1] > 0) rgb_out = 24'h33FF33;
//            else if (in_hit_zone_y && in_rec_x[2] && flash[2] > 0) rgb_out = 24'h33FF33;
//            else if (in_hit_zone_y && in_rec_x[3] && flash[3] > 0) rgb_out = 24'h33FF33;
//                
//					 
//            else if (in_hit_zone_y && draw_zone) 
//                rgb_out = 24'h445566; 
//				
//				else if (fill_rec_0) rgb_out = keys[0] ? 24'hFFFFFF : 24'hFF8800; // FF8800 = orange
//            else if (fill_rec_1) rgb_out = keys[1] ? 24'hFFFFFF : 24'hFF8800;
//            else if (fill_rec_2) rgb_out = keys[2] ? 24'hFFFFFF : 24'hFF8800;
//            else if (fill_rec_3) rgb_out = keys[3] ? 24'hFFFFFF : 24'hFF8800;
// 
//                
//            else if (draw_zone)
//                rgb_out = 24'h222222; //  main background
//                
//            else
//                rgb_out = 24'h000000; 
        end
    end
    // Разбиваем готовый 24-битный цвет на три 8-битных канала
    assign r = rgb_out[23:16];
    assign g = rgb_out[15:8];
    assign b = rgb_out[7:0];

endmodule