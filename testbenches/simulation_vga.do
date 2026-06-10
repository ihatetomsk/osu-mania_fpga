# 1. Создаем рабочую библиотеку
vlib work
vmap work work

# 2. Компилируем исходники
vlog -sv HDMI/vga_generator.sv
vlog -sv testbenches/tb_vga_generator.sv

# 3. Запускаем симулятор
vsim -voptargs="+acc" work.tb_vga_generator

# 4. Настраиваем окно графиков
add wave -divider "System & Config"
add wave -position insertpoint sim:/tb_vga_generator/clk
add wave -position insertpoint sim:/tb_vga_generator/rst
add wave -position insertpoint sim:/tb_vga_generator/mode

add wave -divider "VGA Timing Outputs"
add wave -color Orange -position insertpoint sim:/tb_vga_generator/hsync
add wave -color Orange -position insertpoint sim:/tb_vga_generator/vsync
add wave -color Yellow -position insertpoint sim:/tb_vga_generator/de

add wave -divider "Pixel Coordinates"
add wave -radix unsigned -color Cyan -position insertpoint sim:/tb_vga_generator/x
add wave -radix unsigned -color Cyan -position insertpoint sim:/tb_vga_generator/y

add wave -divider "Internal Counters"
add wave -radix unsigned -position insertpoint sim:/tb_vga_generator/dut/h_cnt
add wave -radix unsigned -position insertpoint sim:/tb_vga_generator/dut/v_cnt

# 5. Запускаем
run -all
wave zoom full