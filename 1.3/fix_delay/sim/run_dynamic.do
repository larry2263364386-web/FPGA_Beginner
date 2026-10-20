# 1. 清理旧工作库
vdel -lib work -all
vlib work
vmap work work

# 2. 编译源码：先编译底层组件，再编译上层模块
vlog ../rtl/simple_dual_port_ram.v
vlog ../rtl/dynamic_delay.v

# 3. 编译测试台
vlog dynamic_delay_tb.v

# 4. 启动仿真：vsim 后跟「库名.模块名」，绝对不能加 .v
# -voptargs=+acc 强制保留所有内部信号，防止被优化掉
vsim -voptargs=+acc work.dynamic_delay_tb

# 5. 添加波形
add wave -radix unsigned *
add wave -radix unsigned /dynamic_delay_tb/u_dut/di_addr
add wave -radix unsigned /dynamic_delay_tb/u_dut/do_addr
add wave -radix unsigned /dynamic_delay_tb/u_dut/do_data

# 6. 波形显示设置
configure wave -timelineunits ns

# 7. 运行仿真并自动缩放
run 1us
wave zoom full
