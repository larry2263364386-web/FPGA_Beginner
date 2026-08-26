// **************************** Declaration ****************************
// File name:        hello_world
// Author:           Larry
// Date:             2026-08-25 23:00
// Version Number:   1.0
// Abstract:         led松开熄灭按住点亮
//                   对比"组合逻辑"与"时序逻辑"两种写法的差异
//
// Board:            Cyclone IV E  EP4CE10F17C8
// Clock:            50 MHz (PIN_E1)
//
// Modification history:(including time, version, author and abstract)
// 2026-08-25 23:00   version 1.0   Larry
// Abstract: Initial
//
// ******************************* end *********************************

// `timescale <仿真时间单位>/<仿真时间精度>
// 只影响仿真，不影响综合出来的硬件；1ns/100ps = 延时以 1ns 计、精确到 0.1ns
`timescale 1ns/100ps

//──────────────────────────────────────────────────────────────────────
//模块功能：按键控制LED
// key_0：按键，低电平按下，组合逻辑直接控制led_0
// key_1：按键，低电平按下，时序逻辑控制led_1
// rst_n：低电平复位；clk：50M系统时钟
//
// 电平约定（由本板硬件决定，务必与原理图一致）：
//   按键：按下 = 低电平 0，松开 = 高电平 1  （按键一端接地，另一端上拉）
//   LED ：输出 0 = 点亮，输出 1 = 熄灭      （LED 阳极接 VCC，阴极接 FPGA 引脚）
//   所以"按住点亮"就是把按键的低电平原样送给 LED —— 两者都是低有效
//
// 学习要点：
//   1. assign 描述一根"导线"：右边一变，左边立刻跟着变（组合逻辑，无存储）
//   2. always @(posedge clk) 描述"寄存器"：只在时钟上升沿更新（时序逻辑，有存储）
//   3. 组合逻辑输出用 wire；时序逻辑输出用 reg，且赋值用非阻塞 <=
//   4. 时序逻辑必带异步复位，保证上电后寄存器有确定的初始状态
//──────────────────────────────────────────────────────────────────────

module hello_world(
    //复位与时钟
    input        rst_n,      //active low, KEY4，异步复位
    input        clk,        //50MHz 系统时钟

    //输入按键信号
    input        key_0,      //按键，低电平有效（按下为 0）
    input        key_1,      //按键，低电平有效（按下为 0）

    //输出LED信号
    output wire  led_0,      //LED，低电平点亮（组合逻辑驱动，故为 wire）
    output reg   led_1       //LED，低电平点亮（时序逻辑驱动，故为 reg）
);

///组合逻辑LED0，低电平点亮
// 三目运算符：key_0 按下(0) → 输出 0 → 灯亮；松开(1) → 输出 1 → 灯灭
// 没有时钟参与，按键一动 LED 立刻响应（只有门电路的纳秒级延时）
// 代价：按键的机械抖动会原封不动地传到 LED 上
assign led_0 = (key_0 == 1'b0) ? 1'b0 : 1'b1;

//时序逻辑LED1，低电平点亮
// 敏感列表里的 negedge rst_n → 异步复位：复位一拉低立即生效，不必等时钟沿
// 赋值用 <=（非阻塞）：时序逻辑的标准写法，让所有寄存器"同时"更新
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        led_1 <= 1'b1; //复位输出高，灯灭
    end
    else if(key_1==1'b0)begin
        led_1 <= 1'b0; //按键按下，输出低，灯亮
    end
    else if(key_1==1'b1)begin
        led_1 <= 1'b1; //按键松开，输出高，灯灭
    end
end
// 注：led_1 比 led_0 最多晚一个时钟周期(20ns)才响应，肉眼完全看不出来


endmodule
