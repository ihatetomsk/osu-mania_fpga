module pattern_gen (
    input  logic clk,       // Тактовая частота 25 МГц (от PLL)
    input  logic rst,       // Сигнал сброса (от кнопки)
    input  logic [9:0] x,   // Текущая координата X (от vga_generator)
    input  logic [9:0] y,   // Текущая координата Y (от vga_generator)
    input  logic de,        // Флаг активного видео (Data Enable)
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
    localparam BLOCK_SIZE = 10'd40; // Размер падающего квадрата 40x40

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            block_y <= 10'd0;
            block_x <= 10'd221; // По умолчанию ставим в крайнюю левую полосу
        end else if (frame_tick) begin
            // Если блок улетел за нижний край экрана
            if (block_y >= 10'd480) begin
                block_y <= 10'd0; // Возвращаем его на самый верх
                
                // Выбираем случайную полосу из 4 возможных на основе 2-х бит LFSR
                case (lfsr[1:0])
                    2'd0: block_x <= 10'd221; // Полоса 1
                    2'd1: block_x <= 10'd274; // Полоса 2
                    2'd2: block_x <= 10'd327; // Полоса 3
                    2'd3: block_x <= 10'd380; // Полоса 4
                endcase
            end else begin
                // Блок продолжает падать
                block_y <= block_y + 10'd3; // Скорость падения (3 пикселя за 1 кадр)
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
    assign draw_block = (x >= block_x) && (x < block_x + BLOCK_SIZE) &&
                        (y >= block_y) && (y < block_y + BLOCK_SIZE);
                        
    // Флаг 2: Левая белая разделительная граница (ширина 2 пикселя)
    assign draw_line_left  = (x == 10'd213) || (x == 10'd214);
    
    // Флаг 3: Правая белая разделительная граница (ширина 2 пикселя)
    assign draw_line_right = (x == 10'd426) || (x == 10'd427);
    
    // Флаг 4: Игровой стакан (пространство между линиями)
    assign draw_zone = (x >= 10'd215) && (x < 10'd426);

    // Главный смеситель (Z-index: что поверх чего рисуется)
    always_comb begin
        if (!de) begin
            rgb_out = 24'h000000;     // В служебной зоне (вне экрана) СТРОГО черный цвет!
        end else begin
            if (draw_block)
                rgb_out = 24'hFF3333; // Слой 1 (Самый верхний): Красный блок
                
            else if (draw_line_left || draw_line_right)
                rgb_out = 24'hFFFFFF; // Слой 2: Белые линии границ
                
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