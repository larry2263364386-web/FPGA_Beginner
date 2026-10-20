// **************************** Declaration ****************************
// File name:        clock_frequency_divider.v
// Author:           Larry
// Date:             2026-10-20
// Version Number:   1.0
// Abstract:         参数化分数分频器：用相位累加器把 clk_in 分频成 clk_out
//                   f_out = f_in × div_N / (2 × div_M)
// Board:            Cyclone IV E  EP4CE10F17C8
// Clock:            50 MHz (PIN_E1)
//
// Modification history:(including time, version, author and abstract)
// 2026-10-20   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
`timescale 1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 模块功能：分数分频器（相位累加器实现）
//   每个时钟周期把 div_N 累加进 count，一旦 count 达到 div_M 就减去 div_M
//   并翻转一次输出。平均每 (div_M / div_N) 个输入时钟翻转一次输出，
//   翻转一次 = 半个周期，所以 f_out = f_in × div_N / (2 × div_M)。
//
//   div_Mbits=9、div_Nbits=1：div_N 只能取 0/1，本工程实际当「÷div_M」整数分频用。
//   例：div_M=10、div_N=1 → 每 10 个时钟翻转一次 → f_out = 50MHz/20 = 2.5MHz。
//
// 学习要点：
//   1. 整数分频（÷N）只能 N 等分、占空比不一定 50%；分数分频靠累加器平均逼近
//   2. clk_out 是寄存器输出（衍生时钟），不要在别处拿它当时钟源——见 1.2「已知问题」
//   3. 复位里 count 赋 32'b0，但 count 实际只有 div_Mbits+2 位，高位被截断
//      —— 功能无碍，规范写法应直接赋 0 或匹配位宽
//──────────────────────────────────────────────────────────────────────

module clock_frequency_divider(
                                reset_l,
                                clk_in,
                                div_M,
                                div_N,
                                clk_out
);
parameter   div_Mbits = 9,
                div_Nbits = 1;
input                       reset_l;            //低有效复位
input                       clk_in;             //输入时钟（50MHz）
input   [div_Mbits-1:0]     div_M;              //分频比 M（本工程即分频系数）
input   [div_Nbits-1:0]     div_N;              //分频比 N（1 位，取值 0/1）
output                      clk_out;            //分频输出

reg     [div_Mbits+1:0]     count;              //相位累加器（比 div_M 多 2 位防溢出）
reg                         clk_out;

always @ (negedge reset_l or posedge clk_in)
    if(reset_l == 1'b0) begin
        count <= 32'b0;                         //复位累加器（实际位宽 11 位，32'b0 被截断，功能无碍）
        clk_out <= 1'b0;
    end
    else begin
        if(count + div_N >= div_M) begin        //累加后达到 div_M → 翻转输出
            count <= count + div_N-div_M;       //减去 div_M，余数留给下一轮，保证平均频率精确
            clk_out <=~clk_out;                 //翻转一次输出
        end
        else begin
            count <= count + div_N;             //未到阈值，继续累加
        end
    end

endmodule
