# ============================================================================
# Скрипт автоматического запуска симуляции в ModelSim для модуля pattern_gen
# ============================================================================

# 1. Очистка консоли и завершение предыдущих сессий симуляции
cls
echo "===================================================="
echo "Starting simulation setup for pattern_gen..."
echo "===================================================="
quit -sim

# 2. Создание и привязка рабочей библиотеки проектирования (work)
if [file exists work] {
    vdel -lib work -all
}
vlib work
vmap work work

# 3. Компиляция файлов проекта на SystemVerilog
# Компилируем память, знакогенератор и сам тестируемый модуль ядра
echo "Compiling design files..."
vlog -sv "ip/rom/my_rom.v"
vlog -sv "HDMI/sprite_combo_logic.sv"
vlog -sv "HDMI/pattern_gen.sv"

# Компиляция файла тестбенча
echo "Compiling testbench..."
vlog -sv "testbenches/tb_pattern_gen.sv"

# 4. Запуск эмулятора/симулятора (Elaboration)
# Подключаем библиотеку altera_mf_ver, так как внутри my_rom используется altsyncram
echo "Elaborating design..."
if {![file exists "../sptites.mif"] && [file exists "sptites.mif"]} {
    echo "Creating a fallback copy of sptites.mif for ModelSim..."
    # Создаем копию на уровень выше, чтобы удовлетворить относительный путь внутри IP-блока
    file copy -force "sptites.mif" "../sptites.mif"
}
vsim -t 1ps -L work -L altera_mf_ver work.tb_pattern_gen

# 5. Настройка временных диаграмм (Добавление сигналов на Wave-панель)
echo "Adding signals to Wave window..."
delete wave *

# Группа внешних портов тестбенча (входы и выходы)
add wave -divider "TB Interfaces"
add wave -hex -color "Yellow"        /tb_pattern_gen/clk
add wave -logic -color "Red"         /tb_pattern_gen/rst
add wave -hex -color "Cyan"          /tb_pattern_gen/mode
add wave -hex -color "Cyan"          /tb_pattern_gen/speed_mode
add wave -hex -color "Cyan"          /tb_pattern_gen/spawn_mode
add wave -hex                        /tb_pattern_gen/x
add wave -hex                        /tb_pattern_gen/y
add wave -logic                      /tb_pattern_gen/de
add wave -hex -color "Orange"        /tb_pattern_gen/keys
add wave -logic -color "Magenta"     /tb_pattern_gen/pause_btn
add wave -hex                        /tb_pattern_gen/r
add wave -hex                        /tb_pattern_gen/g
add wave -hex                        /tb_pattern_gen/b

# Группа мониторинга внутренних переменных и FSM автомата (изнутри DUT)
add wave -divider "DUT Internal State"
add wave -color "Light Blue"         /tb_pattern_gen/dut/state
add wave -decimal -color "Green"     /tb_pattern_gen/dut/hp
add wave -decimal                    /tb_pattern_gen/dut/spawn_timer
add wave -hex                        /tb_pattern_gen/dut/keys_pulse
add wave -hex                        /tb_pattern_gen/dut/block_visible
add wave -hex                        /tb_pattern_gen/dut/block_y

# Полноэкранная подгонка панели сигналов
wave zoomfull

# 6. Запуск процесса симуляции
echo "Running simulation..."
run -all

echo "===================================================="
echo "Simulation Finished. Check the transcript console!"
echo "===================================================="