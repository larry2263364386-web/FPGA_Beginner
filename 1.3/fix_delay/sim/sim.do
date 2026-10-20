# ==============================================
# fix_delay 固定延时模块仿真脚本
# 存放路径：D:\fpaga_homework\1.3\fix_delay\sim\sim.do
# ==============================================

# 1. 清理旧工作库，重建新库
vdel -lib work -all
vlib work
vmap work work

# 2. 编译 RTL 源码（相对路径：sim目录的上一级 → rtl文件夹）
vlog ../rtl/simple_dual_port_ram.v
vlog ../rtl/fix_delay.v

# 3. 编译 Testbench（当前sim目录下）
vlog fix_delay_tb.v

# 4. 启动仿真
# 关键点：vsim 后跟模块名，绝对不能加 .v 后缀
# -voptargs=+acc 开启全信号可见，防止内部信号被优化掉
vsim -voptargs=+acc work.fix_delay_tb

# 5. 添加波形
# 5.1 顶层输入输出信号
add wave -radix unsigned *

# 5.2 待测模块内部关键调试信号（自动添加，不用手动找）
add wave -radix unsigned /fix_delay_tb/u_fix_delay/di_addr
add wave -radix unsigned /fix_delay_tb/u_fix_delay/do_addr
add wave -radix unsigned /fix_delay_tb/u_fix_delay/di_data
add wave -radix unsigned /fix_delay_tb/u_fix_delay/dii_data
add wave -radix unsigned /fix_delay_tb/u_fix_delay/do_data

# 6. 波形显示设置
configure wave -signalnamewidth 1
configure wave -timelineunits ns
configure wave -valuecolwidth 80

# 7. 运行仿真 1 微秒，足够看完10拍完整延时
run 1us

# 8. 自动缩放至全波形
wave zoom full
