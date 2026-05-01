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
    // 1. ГЕНЕРАТОР СЛУЧАЙНЫХ ЧИСЕЛ (LFSR)
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
    // 2. ФИЗИКА И ПОЗИЦИОНИРОВАНИЕ БЛОКА
    // ==========================================
    logic frame_tick;
    // Генерируем короткий импульс 1 раз за кадр (когда луч уходит в невидимую зону)
    assign frame_tick = (x == 10'd639 && y == 10'd479);

    logic [9:0] block_x;
    logic [9:0] block_y;
	 
	 
	 localparam BLOCK_WIDTH  = 10'd52; 
    localparam BLOCK_HEIGHT = 10'd13; 
	 
	 	 //capture zone
	 localparam HIT_Y_START = 10'd400; 
    localparam HIT_Y_END   = 10'd414; 
	 
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
        end else if (frame_tick) begin
            // Если блок улетел за нижний край экрана
				keys_prev <= keys;
				keys_pulse = keys & ~keys_prev;
            if (block_y >= 10'd480) begin
                block_y <= 10'd0; // Возвращаем его на самый верх
                
                // Выбираем случайную полосу из 4 возможных на основе 2-х бит LFSR
                case (lfsr[1:0])
                    2'd0: block_x <= 10'd215; // Полоса 1
                    2'd1: block_x <= 10'd268; // Полоса 2
                    2'd2: block_x <= 10'd321; // Полоса 3
                    2'd3: block_x <= 10'd374; // Полоса 4
                endcase
            end else begin
                // Блок продолжает падать
                block_y <= block_y + 10'd4; // Скорость падения (3 пикселя за 1 кадр)
            end
        end
    end

    // ==========================================
    // 3. ЛОГИКА ОТРИСОВКИ СЛОЕВ (ГРАФИКА)
    // ==========================================
    logic draw_block;
    logic draw_line_left;
    logic draw_line_right;
    logic draw_zone;
    
    logic [23:0] rgb_out; // Внутренний провод для сборки 24-битного цвета
    
    // Флаг 1: Текущий пиксель принадлежит падающему блоку
    assign draw_block = (x >= block_x) && (x < block_x + BLOCK_WIDTH) &&
                        (y >= block_y) && (y < block_y + BLOCK_HEIGHT);
                        
    // Флаг 2: Левая белая разделительная граница (ширина 2 пикселя)
    assign draw_line_left  = (x == 10'd213) || (x == 10'd214);
    
    // Флаг 3: Правая белая разделительная граница (ширина 2 пикселя)
    assign draw_line_right = (x == 10'd426) || (x == 10'd427);
    
    // Флаг 4: Игровой стакан (пространство между линиями)
    assign draw_zone = (x >= 10'd215) && (x < 10'd426);

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
	 
	 
    // Главный смеситель (Z-index: что поверх чего рисуется)
    always_comb begin
        if (!de) begin
            rgb_out = 24'h000000;     // В служебной зоне (вне экрана) СТРОГО черный цвет!
        end else begin
            if (draw_block)
                rgb_out = 24'hFF3333; // Слой 1 (Самый верхний): Красный блок
                
            else if (draw_line_left || draw_line_right)
                rgb_out = 24'hFFFFFF; // Слой 2: Белые линии границ
				
				else if (fill_rec_0) begin
                rgb_out = keys[0] ? 24'hFFFFFF : 24'hFF8800; // FF8800 = Оранжевый
            end
            else if (fill_rec_1) begin
                rgb_out = keys[1] ? 24'hFFFFFF : 24'hFF8800;
            end
            else if (fill_rec_2) begin
                rgb_out = keys[2] ? 24'hFFFFFF : 24'hFF8800;
            end
            else if (fill_rec_3) begin
                rgb_out = keys[3] ? 24'hFFFFFF : 24'hFF8800;
            end
                
            else if (draw_zone)
                rgb_out = 24'h222222; // Слой 3: Темно-серый фон игрового стакана
                
            else
                rgb_out = 24'h000000; // Слой 4 (Фон): Черный цвет по бокам от стакана
        end
    end
    // Разбиваем готовый 24-битный цвет на три 8-битных канала
    assign r = rgb_out[23:16];
    assign g = rgb_out[15:8];
    assign b = rgb_out[7:0];

endmodule