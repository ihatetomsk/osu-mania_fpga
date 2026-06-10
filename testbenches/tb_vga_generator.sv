`timescale 1ns/1ps

module tb_vga_generator();

    // Входы
    logic clk;
    logic rst;
    logic [1:0] mode;

    // Выходы
    logic hsync;
    logic vsync;
    logic de;
    logic [10:0] x;
    logic [10:0] y;

    // Подключение тестируемого модуля
    vga_generator dut (
        .clk   (clk),
        .rst   (rst),
        .mode  (mode),
        .hsync (hsync),
        .vsync (vsync),
        .de    (de),
        .x     (x),
        .y     (y)
    );

    // Генерация клока (имитируем 25 МГц — 40 нс период)
    initial clk = 0;
    always #20 clk = ~clk;

    initial begin
        // Инициализация
        rst = 1;
        mode = 2'b00; // Начинаем с 640x480 @ 60Hz
        #100;
        rst = 0;

        $display("=== VGA Generator Simulation Started ===");
        $display("Testing Mode 00 (640x480)...");

        // 1. Смотрим на строчную развертку (Horizontal)
        // H_TOTAL для 640x480 равен 800 тактов. Подождем 2 полные строки.
        #(800 * 40 * 2);

        // 2. Смотрим на кадровую развертку (Vertical)
        // Чтобы не ждать впустую, используем команду wait, 
        // чтобы симулятор сам тормознул, когда Y дойдет до зоны VSYNC (v_sync_start = 490)
        $display("Waiting for VSYNC zone...");
        wait(dut.v_cnt == 490);
        $display("Reached VSYNC zone!");
        
        // Подождем еще несколько строк, чтобы увидеть импульс VSYNC целиком
        #(800 * 40 * 4);

        // 3. Тест динамической смены разрешения
        @(posedge clk);
        $display("Switching resolution on-the-fly to Mode 01 (800x600)...");
        mode = 2'b01;

        // Дадим поработать в новом режиме пару строк
        // Для 800x600 H_TOTAL равен 1056 тактов
        #(1056 * 40 * 2);

        $display("=== Simulation Finished ===");
        $stop; // Остановка симуляции
    end

endmodule