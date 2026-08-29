// **************************** Declaration ****************************
// File name:        counter_9999.v
// Author:           Larry
// Date:             2026-08-27 20:00
// Version Number:   1.0
// Abstract:         计数到9999然后归为0
// Board:            Cyclone IV E  EP4CE10F17C8
//
// Modification history:(including time, version, author and abstract)
// 2026-08-27 20:00   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
`timescale      1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 0 → 9999 循环计数器
//   位宽：9999 需要 14 位（2^13 = 8192 不够，2^14 = 16384 够）
//   时钟：clk_gen 给的 10Hz，所以每 0.1 秒加 1，数满一圈约 1000 秒
//   归零：必须显式判断"数到 9999 就回 0"。若靠位宽自然溢出，
//         14 位要数到 16383 才回绕，显示就会跑出 9999 变成乱码。
//──────────────────────────────────────────────────────────────────────

module counter_9999(
    input               clk     ,   //计数时钟（10Hz）
    input               reset_l ,   //异步复位，低电平有效
    output  reg [13:0]  counter     //当前计数值 0~9999
);

always @(negedge reset_l or posedge clk)
begin
    if (!reset_l) begin
        counter <= 14'b0            ;
    end
    else begin
        if (counter==14'd9999) begin
            counter     <= 14'b0    ;   //数满归零
        end
        else begin
        counter <= counter+14'b1    ;
        end
    end
end


endmodule