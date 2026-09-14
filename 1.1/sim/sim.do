vlib work
vmap work work
vlog ../rtl/hello_world.v
vlog hello_world_tb.v
vsim -voptargs=+acc hello_world_tb

add wave -noupdate -divider "【时钟 复位 输入按键】"
add wave -noupdate sim:/hello_world_tb/clk
add wave -noupdate sim:/hello_world_tb/reset_l
add wave -noupdate sim:/hello_world_tb/key_0
add wave -noupdate sim:/hello_world_tb/key_1

add wave -noupdate -divider "【输出：LED】"
add wave -noupdate sim:/hello_world_tb/led_0
add wave -noupdate sim:/hello_world_tb/led_1

configure wave -signalnamewidth 1
configure wave -timelineunits ns
update
view wave
run 6000ns
