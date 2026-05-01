module i2c_simple_controller (
    input  logic clk,          // Вход 50 МГц
    input  logic rst,
    input  logic [7:0] addr,   // Адрес чипа (0x72)
    input  logic [7:0] reg_a,  // Адрес регистра
    input  logic [7:0] reg_d,  // Данные
    input  logic start,
    output logic done,
    output logic sclk,
    inout  wire  sdat
);

    // генерация тика 200 кгц для scl в 100кгц
    logic [7:0] clk_div;
    logic en;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div <= 0;
            en <= 0;
        end else if (clk_div == 249) begin
            clk_div <= 0;
            en <= 1;
        end else begin
            clk_div <= clk_div + 1;
            en <= 0;
        end
    end

    // автомат с состояниями low high для каждого бита
    typedef enum logic [4:0] {
        IDLE,
        START1, START2,
        ADDR_LOW, ADDR_HIGH,
        ACK1_LOW, ACK1_HIGH,
        REG_LOW, REG_HIGH,
        ACK2_LOW, ACK2_HIGH,
        DATA_LOW, DATA_HIGH,
        ACK3_LOW, ACK3_HIGH, ACK3_POST,
        STOP1,
        DONE_ST
    } state_t;

    state_t state = IDLE;
    logic [2:0] bit_cnt;
    logic [7:0] shift_reg;
    logic sda_out;
    logic scl_out;

    // управление физическими выводами
    assign sdat = (sda_out) ? 1'bz : 1'b0;
    assign sclk = scl_out;

    // автомат i2c
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            sda_out <= 1;
            scl_out <= 1;
            done <= 0;
        end else begin
            // перехват стартового сигнала на 50 МГц
            if (state == IDLE) begin
                done <= 0;
                sda_out <= 1;
                scl_out <= 1;
                if (start) begin
                    shift_reg <= addr;
                    state <= START1;
                end
            end 
            // Шаги I2C выполняются только по таймеру
            else if (en) begin
                case (state)
                    // start фаза
                    START1: begin
                        sda_out <= 0; // SDA падает при высоком SCL (условие START)
                        scl_out <= 1;
                        state <= START2;
                    end
                    START2: begin
                        scl_out <= 0; // Уроняем SCL, готовы слать данные
                        bit_cnt <= 7;
                        state <= ADDR_LOW;
                    end

                    // фаза передачи байта (адрес)
                    ADDR_LOW: begin
                        sda_out <= shift_reg[bit_cnt]; // бит выставляется пока scl в нуле
                        scl_out <= 0;
                        state <= ADDR_HIGH;
                    end
                    ADDR_HIGH: begin
                        scl_out <= 1; // поднятие scl чтобы читать бит
                        if (bit_cnt == 0) state <= ACK1_LOW;
                        else begin
                            bit_cnt <= bit_cnt - 1;
                            state <= ADDR_LOW;
                        end
                    end

                    // жмем ручки
                    ACK1_LOW: begin
                        sda_out <= 1; // sda отпускаем чип прижмет к нулю
                        scl_out <= 0;
                        state <= ACK1_HIGH;
                    end
                    ACK1_HIGH: begin
                        scl_out <= 1;
                        shift_reg <= reg_a; // следующий бит
                        bit_cnt <= 7;
                        state <= REG_LOW;
                    end

                    //фзаза передачи байта регистр
                    REG_LOW: begin
                        sda_out <= shift_reg[bit_cnt];
                        scl_out <= 0;
                        state <= REG_HIGH;
                    end
                    REG_HIGH: begin
                        scl_out <= 1;
                        if (bit_cnt == 0) state <= ACK2_LOW;
                        else begin
                            bit_cnt <= bit_cnt - 1;
                            state <= REG_LOW;
                        end
                    end

                    // жмем ручку
                    ACK2_LOW: begin
                        sda_out <= 1;
                        scl_out <= 0;
                        state <= ACK2_HIGH;
                    end
                    ACK2_HIGH: begin
                        scl_out <= 1;
                        shift_reg <= reg_d; // установка последний байт данных
                        bit_cnt <= 7;
                        state <= DATA_LOW;
                    end

                    // передача байта данных 
                    DATA_LOW: begin
                        sda_out <= shift_reg[bit_cnt];
                        scl_out <= 0;
                        state <= DATA_HIGH;
                    end
                    DATA_HIGH: begin
                        scl_out <= 1;
                        if (bit_cnt == 0) state <= ACK3_LOW;
                        else begin
                            bit_cnt <= bit_cnt - 1;
                            state <= DATA_LOW;
                        end
                    end

                    // жмем ручки
                    ACK3_LOW: begin
                        sda_out <= 1;
                        scl_out <= 0;
                        state <= ACK3_HIGH;
                    end
                    ACK3_HIGH: begin
                        scl_out <= 1;
                        state <= ACK3_POST;
                    end
                    ACK3_POST: begin
                        scl_out <= 0; // отпускаем scl для установки sda
                        sda_out <= 0; // установка sda к нулю
                        state <= STOP1;
                    end

                    // STOP фаза
                    STOP1: begin
                        scl_out <= 1; // подъем scl
                        state <= DONE_ST;
                    end
                    DONE_ST: begin
                        sda_out <= 1; // затем sda 
                        done <= 1;
                        state <= IDLE;
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule