// **************************** Declaration ****************************
// File name:        clk_gen.v
// Author:           Larry
// Date:             2026-08-27 9:00
// Version Number:   1.0
// Abstract:         输入 50MHz 系统时钟，通过计数器分频，产生 200Hz、10Hz 50%占空比方波时钟
// Board:            Cyclone IV E  EP4CE10F17C8
//
// Modification history:(including time, version, author and abstract)
// 2026-08-27 9:00   version 1.0   Larry
// Abstract: Initial
// 2026-08-29        version 1.1   Larry
// Abstract: 模块名 led_gen → clk_gen，端口 reset_l → reset_l，与顶层 counter_seg 例化对齐
// **************************** end ****************************
`timescale      1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 分频原理：计数器数满 N 个输入时钟就把输出翻转一次
//   翻转一次 = 半个周期 → 输出周期 = 2N 个输入时钟 → f_out = f_in / (2N)
//
//   200Hz：N = 125000（计数 0~124999）  50_000_000 / (2×125000) = 200 Hz  ✓
//          上限 124999 需 17 位，这里给 18 位留余量
//   10Hz ：以 clk_200hz 为时钟，N = 10（计数 0~9）   200 / (2×10) = 10 Hz  ✓
//──────────────────────────────────────────────────────────────────────

module clk_gen(
    input           clk         ,   //50MHz 系统时钟
    input           reset_l     ,   //异步复位，低电平有效
    output  reg     clk_200hz   ,   //200Hz，供数码管动态扫描
    output  reg     clk_10hz        //10Hz，供计数器递增

);

reg     [17:0]      clk_200hz_cnt   ;
reg     [3:0]       clk_10hz_cnt    ;

always @ (negedge reset_l or posedge clk)
begin
    if(!reset_l) begin
        clk_200hz_cnt   <= 18'b0;
        clk_200hz       <= 1'b0;
    end
    else begin
            if(clk_200hz_cnt == 18'd124999) begin
                clk_200hz_cnt       <= 18'b0;
                clk_200hz           <= ~clk_200hz;      //数满翻转，得到 50% 占空比
            end
            else begin
                clk_200hz_cnt       <= clk_200hz_cnt+18'b1;              
            end
    end
end

//200Hz → 10Hz
//注意：这里拿 clk_200hz（寄存器产生的信号）当时钟用，属于"衍生时钟"。
//     入门阶段这样写能跑，工程上更推荐「时钟使能」：全部寄存器统一挂 50MHz，
//     用一个 en 脉冲控制何时更新，时序分析才好做，也避免时钟树资源浪费。
always @ (negedge reset_l or posedge clk_200hz)
begin
    if(!reset_l) begin
        clk_10hz_cnt   <= 4'b0;
        clk_10hz       <= 1'b0;
    end
    else begin
            if(clk_10hz_cnt == 4'd9) begin
                clk_10hz_cnt       <= 4'b0;
                clk_10hz           <= ~clk_10hz;
            end
            else begin
                clk_10hz_cnt       <= clk_10hz_cnt+4'b1;              
            end
    end
end


endmodule