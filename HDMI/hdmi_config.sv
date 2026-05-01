module hdmi_config (
    input  logic clk,
    input  logic rst,
    output logic i2c_sclk,
    inout  wire  i2c_sdat,
    output logic ready
);
    logic [4:0] rom_addr;
    logic [15:0] rom_data;
    logic start, done;

    // список регистров
    always_comb begin
        case (rom_addr)
            5'd0:  rom_data = 16'h4110; // Power up
            5'd1:  rom_data = 16'h9803; 
            5'd2:  rom_data = 16'h9AE0;
            5'd3:  rom_data = 16'h9C30;
            5'd4:  rom_data = 16'h9D01;
            5'd5:  rom_data = 16'hA2A4;
            5'd6:  rom_data = 16'hA3A4;
            5'd7:  rom_data = 16'hE0D0;
            5'd8:  rom_data = 16'hF900;
            5'd9:  rom_data = 16'h1500; // 24-bit RGB 4:4:4
            5'd10: rom_data = 16'h1660; // Output style 1
            5'd11: rom_data = 16'hAF06; // Режим HDMI (не DVI)
            default: rom_data = 16'h0000;
        endcase
    end

    i2c_simple_controller i2c_unit (
        .clk(clk),
        .rst(rst),
        .addr(8'h72), // Адрес ADV7513
        .reg_a(rom_data[15:8]),
        .reg_d(rom_data[7:0]),
        .start(start),
        .done(done),
        .sclk(i2c_sclk),
        .sdat(i2c_sdat)
    );

    typedef enum {IDLE, SEND, NEXT, FINISH} state_t;
    state_t state = IDLE;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            rom_addr <= 0;
            start <= 0;
            ready <= 0;
        end else begin
            case (state)
                IDLE: begin
                    start <= 1;
                    state <= SEND;
                end
                SEND: begin
                    start <= 0;
                    if (done) state <= NEXT;
                end
                NEXT: begin
                    if (rom_addr == 11) begin
                        state <= FINISH;
                        ready <= 1;
                    end else begin
                        rom_addr <= rom_addr + 1;
                        state <= IDLE;
                    end
                end
                FINISH: ready <= 1;
            endcase
        end
    end
endmodule