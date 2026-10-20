# 1. 清理旧工作库，重建新库
vdel -lib work -all
vlib work
vmap work work

# 2. 编译 RTL 源码（相对路径：sim目录的上一级 → rtl文件夹）
vlog ../rtl/signal.v

# 3. 编译 Testbench（当前sim目录下）
vlog signal_tb.v

# 4. 启动仿真
# 关键点：vsim 后跟模块名，绝对不能加 .v 后缀
# -voptargs=+acc 开启全信号可见，防止内部信号被优化掉
vsim -voptargs=+acc work.signal_tb

# 5. 添加波形
# 顶层 tb 信号（激励）
add wave -divider "Testbench Stimulus"
add wave -position end sim:/signal_tb/clk
add wave -position end sim:/signal_tb/reset_l
add wave -position end sim:/signal_tb/exec
add wave -position end sim:/signal_tb/rh_wl

# DUT 输出
add wave -divider "DUT Outputs"
add wave -position end sim:/signal_tb/flag_w
add wave -position end sim:/signal_tb/flag_r
add wave -position end sim:/signal_tb/I2C_start

# DUT 内部信号（观察状态译码和三个计数器）
add wave -divider "DUT Internal"
add wave -position end -radix binary sim:/signal_tb/u_dut/signal
add wave -position end sim:/signal_tb/u_dut/signal_r
add wave -position end sim:/signal_tb/u_dut/signal_w
add wave -position end -radix unsigned sim:/signal_tb/u_dut/cnt_r
add wave -position end -radix unsigned sim:/signal_tb/u_dut/cnt_w
add wave -position end -radix unsigned sim:/signal_tb/u_dut/I2C_start_cnt

# 波形显示基数：计数器用无符号十进制，其余默认
radix -unsigned /signal_tb/u_dut/cnt_r /signal_tb/u_dut/cnt_w /signal_tb/u_dut/I2C_start_cnt


# 6. 运行仿真 1 微秒，足够看完10拍完整延时
run 200us

# 7. 自动缩放至全波形
wave zoom full

