# 1. Создаем рабочую библиотеку
vlib work
vmap work work

# 2. Компилируем исходники библиотеки Altera напрямую (РЕШЕТКУ УБРАЛИ)
vlog -work work "C:/altera/13.0sp1/quartus/eda/sim_lib/altera_mf.v"

# 3. Компилируем исходники. Важен порядок!
vlog -sv ip/rom/my_rom.v
vlog -sv HDMI/sprite_combo_logic.sv
vlog -sv HDMI/pattern_gen.sv
vlog -sv testbenches/tb_pattern_gen.sv

# 4. Запускаем симулятор (ФЛАГ -L УБРАЛИ)
vsim -voptargs="+acc" work.tb_pattern_gen

# 5. Настраиваем окно Wave (добавляем только самое интересное)
add wave -divider "System"
add wave -position insertpoint sim:/tb_pattern_gen/clk
add wave -position insertpoint sim:/tb_pattern_gen/rst
add wave -position insertpoint sim:/tb_pattern_gen/keys

add wave -divider "Internal Game Logic"
add wave -position insertpoint sim:/tb_pattern_gen/dut/frame_tick
add wave -position insertpoint sim:/tb_pattern_gen/dut/spawn_timer
add wave -position insertpoint sim:/tb_pattern_gen/dut/block_visible
add wave -position insertpoint sim:/tb_pattern_gen/dut/block_y
add wave -position insertpoint sim:/tb_pattern_gen/dut/block_lane

add wave -divider "Score & Combo"
add wave -position insertpoint sim:/tb_pattern_gen/dut/combo_ones
add wave -position insertpoint sim:/tb_pattern_gen/dut/combo_tens

# 6. Форматируем отображение (например, массивы показываем в десятичном виде)
radix -decimal

# 7. Запускаем симуляцию
run -all

# 8. Отдаляем график, чтобы увидеть всё
wave zoom full