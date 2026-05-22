module vga_generator (
    input  logic clk,
    input  logic rst,               // KEY[0]
    input  logic [1:0] mode,
    output logic hsync, vsync, de,
    output logic [10:0] x, y
);

    logic [11:0] h_total, v_total, h_res, v_res;
    logic [11:0] h_sync_start, h_sync_end, v_sync_start, v_sync_end;

    always_comb begin
        case (mode)
            2'b00: begin // 640x480 @ 60 Hz
                h_res = 12'd640;  v_res = 12'd480;
                h_total = 12'd800;  v_total = 12'd525;
                h_sync_start = 12'd656; h_sync_end = 12'd752;
                v_sync_start = 12'd490; v_sync_end = 12'd492;
            end
            2'b01: begin // 800x600 @ 60 Hz
                h_res = 12'd800;  v_res = 12'd600;
                h_total = 12'd1056; v_total = 12'd628;
                h_sync_start = 12'd840; h_sync_end = 12'd968;
                v_sync_start = 12'd601; v_sync_end = 12'd605;
            end
            2'b10: begin // 1024x768 @ 60 Hz
                h_res = 12'd1024; v_res = 12'd768;
                h_total = 12'd1344; v_total = 12'd806;
                h_sync_start = 12'd1048; h_sync_end = 12'd1184;
                v_sync_start = 12'd771;  v_sync_end = 12'd777;
            end
            default: begin
                h_res = 12'd640;  v_res = 12'd480;
                h_total = 12'd800;  v_total = 12'd525;
                h_sync_start = 12'd656; h_sync_end = 12'd752;
                v_sync_start = 12'd490; v_sync_end = 12'd492;
            end
        endcase
    end

    logic [11:0] h_cnt, v_cnt;
    logic [1:0] mode_q;
    wire mode_changed = (mode_q != mode);

    always_ff @(posedge clk) mode_q <= mode;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else if (mode_changed) begin
            h_cnt <= 0;   // << сброс при смене разрешения
            v_cnt <= 0;
        end else begin
            if (h_cnt < h_total - 1) h_cnt <= h_cnt + 1;
            else begin
                h_cnt <= 0;
                if (v_cnt < v_total - 1) v_cnt <= v_cnt + 1;
                else v_cnt <= 0;
            end
        end
    end

    assign hsync = ~(h_cnt >= h_sync_start && h_cnt < h_sync_end);
    assign vsync = ~(v_cnt >= v_sync_start && v_cnt < v_sync_end);
    assign de    = (h_cnt < h_res && v_cnt < v_res);
    assign x     = (h_cnt < h_res) ? h_cnt[10:0] : 11'd0;
    assign y     = (v_cnt < v_res) ? v_cnt[10:0] : 11'd0;

endmodule