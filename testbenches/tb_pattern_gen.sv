`timescale 1ns/1ps

module tb_pattern_gen();

    // Входные сигналы
    logic clk;
    logic rst;
    logic [1:0]  mode;
    logic [1:0]  speed_mode;
    logic [1:0]  spawn_mode;
    logic [10:0] x;
    logic [10:0] y;
    logic        de;
    logic [3:0]  keys;

    // Выходные сигналы
    logic [7:0] r, g, b;

    // Генерация клока (25 МГц для режима 640x480)
    initial clk = 0;
    always #20 clk = ~clk;

    // Подключение тестируемого модуля (Device Under Test)
    pattern_gen dut (
        .clk        (clk),
        .rst        (rst),
        .mode       (mode),
        .speed_mode (speed_mode),
        .spawn_mode (spawn_mode),
        .x          (x),
        .y          (y),
        .de         (de),
        .keys       (keys),
        .r          (r),
        .g          (g),
        .b          (b)
    );

    // Задача для быстрой симуляции одного кадра (Frame Tick)
    // Мы прыгаем сразу в конец кадра, чтобы сработала игровая логика
    task simulate_frames(input int frames);
        for (int i = 0; i < frames; i++) begin
            // Устанавливаем координаты конца кадра для 640x480
            x = 11'd639; 
            y = 11'd479;
            @(posedge clk);
            // Сбрасываем координаты
            x = 11'd0; 
            y = 11'd0;
            @(posedge clk);
        end
    endtask

    initial begin
        // Инициализация
        rst = 1;
        mode = 2'b00;       // 640x480
        speed_mode = 2'b00; 
        spawn_mode = 2'b00; // Редкие ноты
        x = 0; y = 0; de = 1;
        keys = 4'b0000;

        #100;
        rst = 0;
        @(posedge clk);

        $display("=== START GAME SIMULATION ===");

        // 1. Ждем спавна первого блока
        // При spawn_mode = 00 интервал равен 50 кадрам
        $display("Simulating 51 frames to spawn a block...");
        simulate_frames(51);

        // 2. Симулируем падение блока
        // HIT_Y_START = 400. Скорость = 2 пикселя/кадр.
        // Блоку нужно примерно 200 кадров, чтобы долететь до зоны поражения.
        $display("Waiting for the block to reach the hit zone...");
        simulate_frames(195); 
        
        // 3. Нажимаем все кнопки подряд (имитируем удар игрока)
        // В реальности мы не знаем, на какой дорожке заспавнился блок (там рандом), 
        // поэтому бьем по всем 4-м, чтобы наверняка выбить комбо.
        @(posedge clk);
        keys = 4'b1111; 
        $display("Key Pressed! (Hitting all lanes)");
        
        // Держим кнопку пару кадров
        simulate_frames(2);
        keys = 4'b0000;
        $display("Key Released!");

        // 4. Ждем еще немного, чтобы убедиться, что комбо обновилось, 
        // а блок удалился (исчез)
        simulate_frames(10);

        $display("=== TEST FINISHED ===");
        $stop; // Останавливаем симуляцию
    end

endmodule