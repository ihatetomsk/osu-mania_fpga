
//Проверяем, что игра стартует в MENU
//Проверяем, что при нажатии кнопки мы переходим в PLAY
//Проверяем, что пауза реально останавливает(переход в PAUSE)
//Автоматически ждем падения блока и проверяем математику: убедиться, что отнялось ровно 10 HP.
// ждем падения ХП до нуля и строго проверяем переход в GAMEOVER

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
    logic        pause_btn;

    // Выходные сигналы
    logic [7:0] r, g, b;


    int current_hp;

    // Генерация клока (25 МГц)
    initial clk = 0;
    always #20 clk = ~clk;

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
        .pause_btn  (pause_btn),
        .r          (r),
        .g          (g),
        .b          (b)
    );

    // Быстрая прокрутка кадров
    task simulate_frames(input int frames);
        for (int i = 0; i < frames; i++) begin
            x = 11'd639; y = 11'd479; de = 1;
            @(posedge clk);
            x = 11'd0; y = 11'd0; de = 0;
            @(posedge clk);
        end
    endtask

    initial begin
        rst = 1;
        mode = 2'b00;       
        speed_mode = 2'b00; 
        spawn_mode = 2'b00; 
        x = 0; y = 0; de = 0;
        keys = 4'b0000;
        pause_btn = 0;

        #100;
        rst = 0;
        @(posedge clk);

        $display("=== STARTING AUTOMATED TESTS ===");

        //  Проверка стартового состояния 
        if (dut.state !== 2'd0) begin // 0 = MENU
            $fatal(1, "TEST 1 FAILED: Game did not start in MENU state!");
        end
        $display("[OK] Test 1: Game booted in MENU state.");


        // 
        keys = 4'b0001; 
        simulate_frames(2); 
        keys = 4'b0000;
        simulate_frames(2);
        
        if (dut.state !== 2'd1) begin // 1 = PLAY
            $fatal(1, "TEST 2 FAILED: Game did not transition to PLAY after key press!");
        end
        $display("[OK] Test 2: Transitioned to PLAY state.");


        // Проверка паузы 
        pause_btn = 1;
        simulate_frames(2);
        pause_btn = 0;
        simulate_frames(2);
        
        if (dut.state !== 2'd2) begin // 2 = PAUSE
            $fatal(1, "TEST 3 FAILED: Game did not enter PAUSE state!");
        end
        $display("[OK] Test 3: Successfully entered PAUSE state.");


        // Удержание паузы
        current_hp = dut.hp;
        simulate_frames(50); // Крутим время, пока игра на паузе
        if (dut.hp !== current_hp || dut.state !== 2'd2) begin
            $fatal(1, "TEST 4 FAILED: State changed or HP dropped while in PAUSE!");
        end
        $display("[OK] Test 4: Game is fully frozen during PAUSE.");


        // Снятие с паузы
        @(posedge clk);          // Ждем положительного фронта тактового сигнала
		  keys <= 4'b0001;         
		 
		  @(posedge clk);          
		  keys <= 4'b0000;         // Отпускаем кнопку
		 
		  repeat(2) @(posedge clk); // Даем автомату 1-2 такта на обновление состояния (state <= next_state)

			// Проверка
		  if (dut.state == 2'b01) begin // Предполагая, что PLAY это 2'b01 (или используйте имя state_t::PLAY)
			  $display("[OK] Test 5: Game successfully returned to PLAY state.");
		  end else begin
			  $fatal(1, "TEST 5 FAILED: Game did not return to PLAY after unpausing! Current state: %b", dut.state);
		  end


        // Проверка механики урона 
        current_hp = dut.hp;
        $display("     Waiting for a block to drop and hit the bottom...");
        
        // Мотаем кадры по одному, пока ХП не изменится
        while (dut.hp == current_hp) begin
            simulate_frames(1);
        end
        
        // ХП изменилось должно отняться ровно 10
        if (dut.hp !== (current_hp - 10)) begin
            $fatal(1, "TEST 6 FAILED: Expected HP to be %0d, but got %0d!", (current_hp - 10), dut.hp);
        end
        $display("[OK] Test 6: Missed block correctly dealt 10 damage! (HP: %0d)", dut.hp);


        // Проверка смерти 
        $display("     Fast-forwarding until HP hits 0...");
        while (dut.hp > 0) begin
            simulate_frames(10); 
        end
        
        simulate_frames(2); 
        
        if (dut.state !== 2'd3) begin // 3 = GAMEOVER
            $fatal(1, "TEST 7 FAILED: HP is 0, but state is not GAMEOVER!");
        end
        $display("[OK] Test 7: Game successfully transitioned to GAMEOVER at 0 HP.");

        $display("      ALL TESTS PASSED SUCCESSFULLY!");
        $stop;
    end

endmodule