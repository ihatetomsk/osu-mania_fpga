module pattern_gen (
    input  logic [9:0] x,
    input  logic [9:0] y,
    input  logic de,
    output logic [7:0] r,
    output logic [7:0] g,
    output logic [7:0] b
);

    always_comb begin
        if (!de) begin
            {r, g, b} = 24'h000000;
        end else begin
            if (x < 213)          // Левая треть
                {r, g, b} = 24'hFF0000; // Красный
            else if (x < 426)     // Средняя треть
                {r, g, b} = 24'h00FF00; // Зеленый
            else                  // Правая треть
                {r, g, b} = 24'h0000FF; // Синий
        end
    end

endmodule