// **************************** Declaration ****************************
// File name:        sop_eop_gen.v
// Author:           Larry
// Date:             2026-10-20
// Version Number:   1.0
// Abstract:         数据包 SOP/EOP 指示生成器：对 i_en 打拍 + 边沿检测，
//                   输出包起始(o_sop)/包结束(o_eop)/包尾错误(o_err)
// Board:            Cyclone IV E  EP4CE10F17C8
// Clock:            50 MHz (PIN_E1)
//
// Modification history:(including time, version, author and abstract)
// 2026-10-20   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
`timescale 1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 模块功能：数据包起始/结束指示生成器
//   把输入有效标志 i_en 打一拍得到 i_en_d0，再用边沿检测：
//   · o_sop = i_en & ~i_en_d0   （i_en 上升沿 = 包起始，只持续 1 拍）
//   · o_eop = ~i_en & i_en_d0   （i_en 下降沿 = 包结束，只持续 1 拍）
//   · o_err = o_eop & i_err_d0  （错误只在包尾采信——设计只看最后一拍）
//   o_en / o_data 则是 i_en / i_data 延迟一拍输出，与 o_sop 对齐。
//
//   概念上类似 AXI-Stream 的 valid/tlast：i_en≈valid，o_eop≈tlast。
//   无引脚绑定，配合 ModelSim / SignalTap 做时序验证。
//
// 学习要点：
//   1. 边沿检测的经典写法：当前拍 & 上一拍取反，单拍脉冲不会多不会漏
//   2. 打拍对齐：i_data / i_err 都要同步打一拍，否则和 o_sop 错位
//   3. 组合输出（assign）实时跟随时序输出（reg），本模块 o_eop 由组合逻辑
//      从「当前 i_en + 上一拍 i_en_d0」算出，见 tb 里 EOP 窗口的检查时机
//──────────────────────────────────────────────────────────────────────

module sop_eop_gen(
                    clk,
                    clk_en,
                    reset_l,
                    i_en,
                    i_err,
                    i_data,
                    o_sop,
                    o_en,
                    o_data,
                    o_eop,
                    o_err
                    );

parameter data_width = 8;

input                   clk;
input                   clk_en;
input                   reset_l;
input                   i_en;       //输入有效标志（一包内连续为高）
input                   i_err;      //输入错误标志（随数据拍给）
input  [data_width-1:0] i_data;     //输入数据

output                  o_sop;      //包起始（i_en 上升沿，1 拍）
output                  o_en;       //输出有效（i_en 打一拍）
output  [data_width-1:0] o_data;    //输出数据（i_data 打一拍）
output                  o_eop;      //包结束（i_en 下降沿，1 拍）
output                  o_err;      //包尾错误（EOP 拍且最后一拍 i_err 为高）


reg                     i_en_d0;        //i_en 打一拍
reg  [data_width-1:0]   i_data_d0;      //i_data 打一拍
reg                     o_sop;          //包起始寄存器
reg                     i_err_d0;       //i_err 打一拍


always @(negedge reset_l or posedge clk) begin
    if (reset_l == 1'b0) begin
        i_en_d0   <= 1'b0;
        i_data_d0 <= {data_width{1'b0}};
        o_sop     <= 1'b0;
        i_err_d0  <= 1'b0;
    end
    else begin
        if (clk_en == 1'b1) begin
            i_en_d0   <= i_en;           //打拍：上一拍的有效标志
            i_data_d0 <= i_data;         //打拍：上一拍的数据
            i_err_d0  <= i_err;          //打拍：上一拍的错误标志
            o_sop <= i_en & (~i_en_d0);  //i_en 上升沿 → 包起始
        end
    end
end

assign o_en     = i_en_d0;              //输出有效 = 延迟一拍的 i_en

assign o_data   = i_data_d0;            //输出数据 = 延迟一拍的 i_data

assign o_eop    = ~i_en & i_en_d0;      //i_en 下降沿 → 包结束

assign o_err    = o_eop & i_err_d0;     //仅在包尾采信错误标志

endmodule
