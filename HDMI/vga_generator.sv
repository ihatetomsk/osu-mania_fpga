module vga_generator (
    input  logic clk,
    output logic hsync, vsync, de,
    output logic [9:0] x, y
);
    // Параметры 640x480 @ 60Hz (Pixel Clock = 25.175 MHz)
    integer h_cnt = 0, v_cnt = 0;

    always_ff @(posedge clk) begin
        if (h_cnt < 799) h_cnt <= h_cnt + 1;
        else begin
            h_cnt <= 0;
            if (v_cnt < 524) v_cnt <= v_cnt + 1;
            else v_cnt <= 0;
        end
    end

    assign hsync = ~(h_cnt >= 656 && h_cnt < 752);
    assign vsync = ~(v_cnt >= 490 && v_cnt < 492);
    assign de    = (h_cnt < 640 && v_cnt < 480);
    assign x     = (h_cnt < 640) ? h_cnt[9:0] : 0;
    assign y     = (v_cnt < 480) ? v_cnt[9:0] : 0;
endmodule