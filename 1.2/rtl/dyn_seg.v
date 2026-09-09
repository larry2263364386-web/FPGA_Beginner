// **************************** Declaration ****************************
// File name:        dyn_seg.v
// Author:           Larry
// Date:             2026-08-27 20:00
// Version Number:   1.0
// Abstract:         四位数码管动态扫描——轮流点亮每一位，靠视觉暂留看成同时显示
// Board:            Cyclone IV E  EP4CE10F17C8
//
// Modification history:(including time, version, author and abstract)
// 2026-08-27 20:00   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
`timescale      1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 动态扫描原理：
//   四位数码管的段选(a~g,dp)是并联的，只有位选分开。所以同一时刻只能显示一位。
//   做法：飞快地轮流点亮 第0位→第1位→第2位→第3位→…，每位亮的瞬间送对应段码。
//   只要轮一圈的频率 > ~50Hz，人眼的视觉暂留就会把它看成四位同时亮着。
//
//   本模块 clk = 200Hz，cnt_show 四个状态轮一圈 → 刷新率 200/4 = 50Hz，刚好不闪。
//
// 三步流水：
//   ① cnt_show  自由计数 0→1→2→3→0…，决定"现在轮到第几位"
//   ② seg_s     位选，低有效 one-hot（4'b1110/1101/1011/0111），一次只选通一位
//   ③ hex→seg   把该位的数字查表转成七段段码
//──────────────────────────────────────────────────────────────────────

module dyn_seg(
    input               clk     ,   //扫描时钟（200Hz）
    input               reset_l ,   //异步复位，低电平有效
    input       [13:0]  data    ,   //待显示的数值 0~9999
    output  reg [3:0]   seg_s   ,   //位选，低有效 one-hot（0 选通）
    output  reg [7:0]   seg         //段选 {dp,g,f,e,d,c,b,a}
);

reg     [1:0]   cnt_show    ;   //扫描位置计数器，2 位自动 0~3 循环
wire    [3:0]   data0       ;   //千位
wire    [3:0]   data1       ;   //百位
wire    [3:0]   data2       ;   //十位
wire    [3:0]   data3       ;   //个位
reg     [3:0]   hex         ;   //当前要显示的那一位数字

//① 扫描位置计数器：2 位寄存器加到 3 自然回绕到 0，不用写归零判断
always @ (negedge reset_l or posedge clk)
begin
    if (!reset_l) begin
        cnt_show <= 2'b0;
    end
    else begin
        cnt_show <= cnt_show + 2'b1;
    end
end

//② 位选：低有效 one-hot 编码，4'b1110 选通第 0 位，4'b1101 选通第 1 位……
//   哪一位对应物理上最左边的数码管，取决于板子接线，现象不对就调这里的顺序
always @ (negedge reset_l or posedge clk)
begin
    if (!reset_l) begin
        seg_s <= 4'b1111;
    end
    else begin
        case(cnt_show[1:0])
            2'b00 :  seg_s <= 4'b1110;    
            2'b01 :  seg_s <= 4'b1101;
            2'b10 :  seg_s <= 4'b1011;
            2'b11 :  seg_s <= 4'b0111;
            default: seg_s <= 4'b1111;
        endcase
    end
end

//十进制拆位：9999 → 千9 百9 十9 个9
//  注意：/ 和 % 会综合出除法器，比较费资源。除数是常数时 Quartus 会优化成
//  乘法+移位，这个规模没问题；位宽再大就该换 BCD 转换（双重拨码 double-dabble）。
assign data0 = data/1000    ;   //千位
assign data1 = data%1000/100;   //百位
assign data2 = data%100/10  ;   //十位
assign data3 = data%10      ;   //个位


//③-a 选出当前扫描位对应的数字（纯组合逻辑，用阻塞赋值 =）
always @ (*)
begin
    case(cnt_show[1:0])
        2'b00 : hex = data0;
        2'b01 : hex = data1;
        2'b10 : hex = data2;
        2'b11 : hex = data3;
        default:hex = 4'b0 ;
    endcase
 end
 
//③-b 七段译码查表
//    段码位序 {dp,g,f,e,d,c,b,a}，本表按「共阴数码管」写：段位= 1 点亮
//    例：数字 0 = 亮 a,b,c,d,e,f 灭 g,dp = 8'b0011_1111
//    若板子是共阳数码管，把整张表按位取反即可（或在输出处加一级 ~）
always @ (negedge reset_l or posedge clk)
begin
    if (!reset_l) begin
        seg     <= 8'b0;
    end
    else begin
        case(hex)
            4'h0: seg   <= 8'b00111111;
            4'h1: seg   <= 8'b00000110;
            4'h2: seg   <= 8'b01011011;
            4'h3: seg   <= 8'b01001111;
            4'h4: seg   <= 8'b01100110;
            4'h5: seg   <= 8'b01101101;
            4'h6: seg   <= 8'b01111101;
            4'h7: seg   <= 8'b00000111;
            4'h8: seg   <= 8'b01111111;
            4'h9: seg   <= 8'b01101111;
            default:seg <= 8'b00000000;
        endcase
    end
end


endmodule
