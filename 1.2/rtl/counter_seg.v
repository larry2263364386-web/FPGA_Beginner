// **************************** Declaration ****************************
// File name:        counter_seg.v
// Author:           Larry
// Date:             2026-08-27 20:00
// Version Number:   1.0
// Abstract:         顶层模块——0~9999 循环计数，四位数码管动态扫描显示
// Board:            Cyclone IV E  EP4CE10F17C8
//
// Modification history:(including time, version, author and abstract)
// 2026-08-27 20:00   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
`timescale      1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 顶层只做一件事：例化三个子模块、用 wire 把它们连起来，自己不写逻辑。
// 这是层次化设计的基本样式——顶层是"接线板"，功能都在子模块里。
//
//   clk 50MHz ─→ clk_gen ─┬─ clk_200hz ─→ dyn_seg      （扫描，每位 50Hz 不闪）
//                         └─ clk_10hz  ─→ counter_9999 （每 0.1s 加 1）
//                                              │
//                                          counter[13:0]
//                                              ↓
//                                           dyn_seg ─→ seg_s[3:0] 位选
//                                                   └→ seg[7:0]   段选
//
// 例化用「具名端口连接」.port(signal)，而不是按位置连接——
// 端口一多，位置连接极易接错且看不出来。
//──────────────────────────────────────────────────────────────────────

module counter_seg(
    input               clk     ,   //50MHz 系统时钟
    input               reset_l ,   //异步复位，低电平有效
    output      [3:0]   seg_s   ,   //数码管位选（4 位共阴数码管）
    output      [7:0]   seg         //数码管段选 {dp,g,f,e,d,c,b,a}
);

//子模块之间的连线：顶层自己不驱动，所以是 wire
wire            clk_200hz   ;
wire            clk_10hz    ;
wire    [13:0]  counter     ;

clk_gen u_clk_gen (
    .clk        ( clk       ),
    .reset_l    ( reset_l   ),
    .clk_200hz  ( clk_200hz ),
    .clk_10hz   ( clk_10hz  )
);

counter_9999 u_counter_9999(
    .clk        ( clk_10hz  ),
    .reset_l    ( reset_l   ),
    .counter    ( counter   )
);

dyn_seg u_dyn_seg (
    .clk        ( clk_200hz ),
    .reset_l    ( reset_l   ),
    .data       ( counter   ),
    .seg_s      ( seg_s     ),
    .seg        ( seg       )
);

endmodule
