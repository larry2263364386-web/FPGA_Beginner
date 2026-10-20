// **************************** Declaration ****************************
// File name:        dynamic_delay.v
// Author:           Larry
// Date:             2026-10-20
// Version Number:   1.0
// Abstract:         动态延迟线：延迟值 delay_cycles 运行时可变（4 位，0~15）
//                   实现同 fix_delay，用双口 RAM 环形缓冲
// Board:            Cyclone IV E  EP4CE10F17C8
// Clock:            50 MHz (PIN_E1)
//
// Modification history:(including time, version, author and abstract)
// 2026-10-20   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
`timescale 1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 模块功能：动态延迟线（delay_cycles 是运行时输入，不再是 parameter）
//   与 fix_delay.v 的区别：延迟值可以在运行中随时改，用同一套双口 RAM 实现。
//
//   注意：delay_cycles 为 0/1 时，组合逻辑会把 data_out 强制接到 data_in/di_data，
//   此时下面的地址计算（di_addr >= delay_cycles-1，无符号会下溢）已经不重要——
//   因为输出被覆盖了。这是「组合输出旁路」救场的典型写法，不是 bug。
//
// 学习要点：
//   1. 延迟可变 → 地址位宽按最大延迟固定（delay_width=4 → 最多 2^4=16 级）
//   2. 参数化（fix_delay）vs 端口化（dynamic_delay）的取舍：前者省资源、后者灵活
//──────────────────────────────────────────────────────────────────────

module dynamic_delay (
    clk,
    reset_l,
    clk_en,
    delay_cycles,
    data_in,
    data_out
);

parameter delay_width = 4;          //延迟值位宽（最大 2^4-1=15）
parameter data_width = 8;           //数据位宽
parameter ram_type = "registers";   //RAM 类型

input clk;
input reset_l;
input clk_en;
input  [delay_width-1:0] delay_cycles;   //运行时延迟周期数（0~15）
input  [data_width-1:0]  data_in;
output [data_width-1:0]  data_out;

reg [data_width-1:0]  data_out;
reg [delay_width-1:0] di_addr;       //RAM 写地址（写指针）
reg [delay_width-1:0] do_addr;       //RAM 读地址（读指针）
reg [data_width-1:0]  di_data;       //data_in 打一拍（供 delay_cycles==1 用）
wire [data_width-1:0] do_data;       //RAM 读出的数据

always @ (negedge reset_l or posedge clk)
    if(reset_l == 1'b0) begin
        di_addr <= 0;
        do_addr <= 0;
        di_data <= 0;
    end
    else begin
        if(clk_en == 1'b1) begin
            di_data <= data_in;
            if(di_addr >= delay_cycles-1) begin   //写指针到顶回绕
                di_addr <= 0;
            end
            else begin
                di_addr <= di_addr + 1;
            end
            do_addr <= di_addr + 2;              //读指针 = 写指针 + 2（环形错位）
            if(di_addr == delay_cycles-2) begin   //回绕补偿
                do_addr <= 0;
            end
            if(di_addr == delay_cycles-1) begin
                do_addr <= 1;
            end
        end
    end

//数据输出选择：delay_cycles 为 0/1 时绕过 RAM
always @ (*)
begin
    data_out = do_data;
    if(delay_cycles == 0) begin
        data_out = data_in;
    end
    if(delay_cycles == 1) begin
        data_out = di_data;
    end
end

simple_dual_port_ram # (
    .addr_width(delay_width),
    .data_width(data_width),
    .ram_type  (ram_type)
) u_dly_data_buf(
    .aclk    (clk),
    .aclk_en (clk_en),
    .awr_en  (1'b1),
    .awr_addr(di_addr),
    .awr_data(data_in),
    .bclk    (clk),
    .bclk_en (clk_en),
    .brd_addr(do_addr),
    .brd_data(do_data)
);

endmodule
