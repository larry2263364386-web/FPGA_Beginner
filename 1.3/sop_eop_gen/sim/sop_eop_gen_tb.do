#==============================================================================
# ModelSim / QuestaSim 仿真脚本：sop_eop_gen_tb.do
# 被测模块：../rtl/sop_eop_gen.v   测试台：sop_eop_gen_tb.v（当前 sim 目录）
#
# 使用方法：
#   cd 到 sim 目录后，在 Transcript 窗口输入：do sop_eop_gen_tb.do
#   或命令行：vsim -do sop_eop_gen_tb.do
#==============================================================================

#---------- 1. 清理旧环境（容错写法：第一次运行也不会报错）----------

# 关闭可能已打开的仿真。
#   【易错点】正确命令是 quit -sim，不是 ".quit sim"。
#   ModelSim 的 "." 前缀只能用于少数内置命令（如 .main clear），
#   并不存在 .quit 这个命令，所以会报：invalid command name ".quit"
#   catch 的作用：命令报错也不中断脚本（第一次运行时本来就没有仿真在跑）。
catch {quit -sim}

# 删除旧的 work 库。
#   第一次运行时库不存在，直接 vdel 会报 vdel-19 并中断脚本。
#   用 catch 包住即可忽略；等价写法：
#       if {[file exists work]} { vdel -lib work -all }
catch {vdel -lib work -all}

#---------- 2. 建库并编译 ----------
vlib work
vmap work work

# 编译 RTL（相对路径：sim 目录的上一级 → rtl 文件夹，按实际路径修改）
vlog ../rtl/sop_eop_gen.v

# 编译 Testbench（当前 sim 目录下）
vlog sop_eop_gen_tb.v

#---------- 3. 启动仿真 ----------
# vsim 后跟模块名（不能加 .v 后缀）
# -voptargs=+acc 开启全信号可见，防止 DUT 内部信号被优化掉
vsim -voptargs=+acc work.sop_eop_gen_tb

#---------- 4. 添加波形 ----------
# tb 激励信号
add wave -divider "Testbench Stimulus"
add wave -position end sim:/sop_eop_gen_tb/clk
add wave -position end sim:/sop_eop_gen_tb/clk_en
add wave -position end sim:/sop_eop_gen_tb/reset_l
add wave -position end sim:/sop_eop_gen_tb/i_en
add wave -position end sim:/sop_eop_gen_tb/i_err
add wave -position end -radix hex sim:/sop_eop_gen_tb/i_data

# DUT 输出
add wave -divider "DUT Outputs"
add wave -position end sim:/sop_eop_gen_tb/o_sop
add wave -position end sim:/sop_eop_gen_tb/o_en
add wave -position end -radix hex sim:/sop_eop_gen_tb/o_data
add wave -position end sim:/sop_eop_gen_tb/o_eop
add wave -position end sim:/sop_eop_gen_tb/o_err

# DUT 内部信号（打一拍寄存器组）
add wave -divider "DUT Internal"
add wave -position end sim:/sop_eop_gen_tb/u_dut/i_en_d0
add wave -position end -radix hex sim:/sop_eop_gen_tb/u_dut/i_data_d0
add wave -position end sim:/sop_eop_gen_tb/u_dut/i_err_d0

#---------- 5. 运行仿真 ----------
# run -all：一直跑到 tb 自己的 $finish（tb 内含 200us 超时看门狗兜底）
run -all

#---------- 6. 波形缩放到全局 ----------
wave zoom full

# Transcript 中的 OK/FAIL 即测试结果，最后应看到 ALL TESTS PASSED
