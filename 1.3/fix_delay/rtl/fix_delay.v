// **************************** Declaration ****************************
// File name:        fix_delay.v
// Author:           Larry
// Date:             2026-10-20
// Version Number:   1.0
// Abstract:         固定延迟线：把 data_in 延迟 delay_cycles 个时钟周期后从 data_out 输出
//                   延迟 ≤2 用寄存器打拍；>2 用双口 RAM 环形缓冲
// Board:            Cyclone IV E  EP4CE10F17C8
// Clock:            50 MHz (PIN_E1)
//
// Modification history:(including time, version, author and abstract)
// 2026-10-20   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
`timescale 1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 模块功能：固定延迟线（delay_cycles 在编译期通过 parameter 固定）
//   把 data_in 延迟 delay_cycles 个时钟周期输出。实现分两档：
//   · delay_cycles ≤ 2：直接用 di_data / dii_data 两级寄存器打拍（省 RAM）
//   · delay_cycles  > 2：用 simple_dual_port_ram 做环形缓冲
//     写指针 di_addr 顺序写，读指针 do_addr = di_addr + 2（循环），
//     即从「两拍之前」的位置读，配合打拍凑出总延迟
//
//   配套 dynamic_delay.v（延迟值运行时可变），二者共享 simple_dual_port_ram.v
//
// 学习要点：
//   1. fun_log2：常数函数求 ceil(log2(delay_cycles))，让 RAM 地址位宽随
//      delay_cycles 自动推导，不用手算
//   2. generate if：按 delay_cycles 是否 >2 决定要不要例化 RAM，省资源
//   3. 环形缓冲 + 读写指针错位 = 数字延迟线，是 FIFO / 移位寄存器链的雏形
//──────────────────────────────────────────────────────────────────────

module fix_delay (
        clk,
        reset_l,
        clk_en,
        data_in,
        data_out
        );

parameter delay_cycles = 10;        //延迟周期数
parameter data_width = 8;           //数据位宽
parameter ram_type = "registers";   //RAM 类型："registers"（寄存器）或 "M9K"（块RAM）

//常数函数：求 ceil(log2(x))，即表示 x 个地址需要的最少位数
function integer fun_log2;
input integer data_in;
integer cnt;
integer div;
begin
    div=data_in-1;
    cnt=0;
    while(div >0) begin
        div = div/2;
        cnt = cnt+1;
    end
    fun_log2 = cnt;
end
endfunction

parameter addr_width=fun_log2(delay_cycles);    //RAM 地址位宽，随 delay_cycles 自动推导

input                       clk;
input                       reset_l;
input                       clk_en;
input   [data_width-1:0]    data_in;
output reg [data_width-1:0] data_out;

reg     [addr_width-1:0]	di_addr;     //RAM 写地址（写指针）
reg     [addr_width-1:0]	do_addr;     //RAM 读地址（读指针）
reg     [data_width-1:0]	di_data;     //data_in 打一拍（供 delay_cycles==1 用）
reg     [data_width-1:0]	dii_data;    //data_in 打两拍（供 delay_cycles==2 用）
wire    [data_width-1:0]	do_data;     //RAM 读出的数据

always @ (negedge reset_l or posedge clk)
    if(reset_l == 1'b0) begin
        di_addr <= 0;
        do_addr <= 0;
        di_data <= 0;
        dii_data <= 0;
    end
    else begin
        if(clk_en == 1'b1) begin
            di_data <= data_in;              //打第一拍
            dii_data <= di_data;             //打第二拍

            if(di_addr >= delay_cycles-1) begin   //写指针到顶回绕
                di_addr<= 0;
            end
            else begin
                di_addr <= di_addr + 1;
            end

            do_addr <= di_addr + 2;              //读指针 = 写指针 + 2（环形错位）

            if(di_addr == delay_cycles-2) begin   //回绕补偿：+2 越界时折回
                do_addr <= 0;
            end

            if(di_addr == delay_cycles-1) begin
                do_addr <= 1;
            end
        end
    end

//数据输出选择：delay_cycles 为 0/1/2 时绕过 RAM，直接用直连/打拍结果
always @ (*)
    begin
        data_out = do_data;
        if(delay_cycles==0)begin
            data_out = data_in;
        end
        if(delay_cycles==1)begin
            data_out = di_data;
        end
        if(delay_cycles==2)begin
            data_out = dii_data;
        end
    end

generate
    if (delay_cycles > 2 ) begin : delay_using_ram_generation
    simple_dual_port_ram # (
        .addr_width(addr_width),
        .data_width(data_width),
        .ram_type  (ram_type)
    )
    u_dly_data_buf(
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
    end
endgenerate

endmodule
