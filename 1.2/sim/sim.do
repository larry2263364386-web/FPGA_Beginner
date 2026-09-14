vlib work
vmap work work

vlog ../rtl/clk_gen.v
vlog ../rtl/counter_9999.v
vlog ../rtl/dyn_seg.v
vlog ../rtl/counter_seg.v
vlog counter_seg_tb.v

vsim -voptargs=+acc counter_seg_tb

add wave -noupdate -divider "【时钟 复位 输入数据】"
add wave sim:/counter_seg_tb/clk
add wave sim:/counter_seg_tb/reset_l
add wave sim:/counter_seg_tb/data

add wave -noupdate -divider "【输出：位选seg_s 段选seg】"
add wave sim:/counter_seg_tb/seg_s
add wave sim:/counter_seg_tb/seg

configure wave -signalnamewidth 1
configure wave -timelineunits ns
update

run 100000ns



