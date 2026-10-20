`timescale 1ns / 1ps
//==============================================================================
// 测试平台（Testbench）：signal_tb
// 被测模块（DUT, Design Under Test）：signal —— I2C 读/写请求锁存 + 时钟展宽
//------------------------------------------------------------------------------
// 【什么是 testbench？】
//   仿真用的"测试台"。它自己产生时钟、复位、输入信号，喂给被测模块，
//   然后检查被测模块的输出是否符合预期，用来验证模块逻辑对不对。
//   它不需要上板，只在仿真工具（iverilog / ModelSim / Vivado）里运行。
//
// 【`timescale 1ns / 1ps 是什么意思？】
//   1ns  = 时间单位：代码里写 #20 就表示 20ns（延迟/周期的单位）
//   1ps  = 时间精度：仿真时间能细分到 1ps（比如 #10.5 里的 0.5ns 能精确表示）
//   本 tb 用 20ns 的时钟周期 → 对应 50MHz 时钟（1/50M = 20ns）
//
// 【整体思路】
//   1. 复位：把 reset_l 拉低一段时间再拉高，让模块回到初始状态；
//   2. 发激励：像真实使用一样，给 exec/rh_wl 发"写请求""读请求"；
//   3. 看输出：检查 flag_w / flag_r / I2C_start 是否按预期变化；
//   4. 自动判错：所有检查都通过 → 打印 ALL TESTS PASSED。
//
// 运行方式（iverilog）：
//   iverilog -g2005 -o sim signal.v signal_tb.v   // 编译两个文件成一个可执行文件
//   vvp sim                                       // 运行仿真
// 波形查看：运行后生成 signal_tb.vcd，用 GTKWave 打开：
//   gtkwave signal_tb.vcd
//
// 注意：
//   1. 被测模块若未修复"复位不完整"的问题（flag_r/flag_w 未复位、
//      I2C_start_cnt 未复位），复位后的初值检查会报 FAIL，这是模块本身的
//      bug 导致的，不是 tb 的问题，建议先修复再仿真。
//   2. $display 里显示的标签用 ASCII 字符，避免终端乱码。
//==============================================================================
module signal_tb;

//----------------- 常量定义（localparam = 局部常量，仿真中不可修改） -----------------
localparam CLK_PERIOD = 20;        // 时钟周期 20ns（50MHz）
localparam HALF       = CLK_PERIOD/2;   // 半周期 = 10ns，用于翻转时钟
localparam MIN_W      = 120;       // 展宽宽度检查的下限（拍）
localparam MAX_W      = 150;       // 展宽宽度检查的上限（拍）

//----------------- 信号声明 -----------------
// 给 DUT 的"输入"信号：测试台要给它赋值，所以用 reg（寄存器变量，可在
// initial/task 中用 = 赋值）
reg  clk      = 1'b0;              // 时钟，初始值给 0
reg  reset_l  = 1'b0;              // 复位（低有效），初始先处于复位态
reg  exec     = 1'b0;              // 执行脉冲（高电平表示有一次 I2C 请求）
reg  rh_wl    = 1'b0;              // 读写选择：0=写，1=读

// DUT 的"输出"信号：由 DUT 驱动，测试台只能读、不能写，所以用 wire（线网）
wire flag_w;                       // 写标志（展宽后的写请求窗口）
wire flag_r;                       // 读标志（展宽后的读请求窗口）
wire I2C_start;                    // I2C 起始信号

integer errors = 0;                // 错误计数器：检查失败一次就 +1，最后汇总
integer cnt;                       // 临时变量：存放测到的展宽拍数

//----------------- 被测模块例化（把 DUT 接进来） -----------------
// 例化语法：模块名 实例名( .端口名(连接的信号), ... )
// 这里把 tb 里的 reg/wire 一一接到 DUT 的同名端口上
signal u_dut(
    .clk      (clk),
    .reset_l  (reset_l),
    .exec     (exec),
    .rh_wl    (rh_wl),
    .flag_w   (flag_w),
    .flag_r   (flag_r),
    .I2C_start(I2C_start)
);

//----------------- 时钟生成 -----------------
// always 块：从仿真开始起反复执行。每 10ns 把 clk 翻转一次，
// 0→1→0→1…… 就形成周期 20ns 的方波时钟。
// 这里只有一个赋值语句，用 = 或 <= 结果相同。
always #HALF clk = ~clk;

//----------------- 超时看门狗（保险丝） -----------------
// initial 块：仿真开始（t=0）时执行一次，然后按里面的延迟顺序往下走。
// 这里的作用：如果主流程卡死（比如某个 wait() 永远等不到信号变化），
// 200us 后强制 $finish 结束仿真，避免无限跑下去。
// 正常情况主流程会远早于 200us 自己结束（谁先 $finish 谁生效）。
initial begin
    #200_000;                      // 等 200000ns = 200us
    $display("[%0t] TIMEOUT: 测试超时，可能有信号未按要求变化", $time);
    $finish;                       // 结束仿真
end

//----------------- 检查任务 1：检查信号应为低电平 -----------------
// task = 可复用的代码段，像函数一样调用。
// input [8*32-1:0] name：字符串参数（32 字节宽，用来存名字，仅用于打印）
// input val：被检查的信号的值
// 为什么用 !== 而不是 !=？
//   != 是"逻辑比较"，遇到 X/Z 会得到未知结果，if 里按假处理 → 会漏报；
//   !== 是"全等比较"，连 X/Z 一起精确比较 → 能抓出信号是 X（未复位）的问题。
task check_low(input [8*32-1:0] name, input val);
    begin
        if (val !== 1'b0) begin                    // 不是精确的 0 → 报错
            $display("[%0t] FAIL: %0s 应为 0，实际为 %b", $time, name, val);
            errors = errors + 1;                   // 错误计数 +1
        end
        else
            $display("[%0t] OK  : %0s = 0", $time, name);
    end
endtask

//----------------- 检查任务 2：检查信号应为高电平 -----------------
task check_high(input [8*32-1:0] name, input val);
    begin
        if (val !== 1'b1) begin
            $display("[%0t] FAIL: %0s 应为 1，实际为 %b", $time, name, val);
            errors = errors + 1;
        end
        else
            $display("[%0t] OK  : %0s = 1", $time, name);
    end
endtask

//----------------- 激励任务：发送一次请求 -----------------
// kind=0 → 写请求；kind=1 → 读请求
// 时序设计（关键点）：
//   在"时钟低电平期间"（negedge 之后）把 exec 拉高，维持到下一个 negedge
//   再拉低，这样 exec 的高电平恰好覆盖一个完整的时钟周期，
//   中间的 posedge 一定能采样到 exec=1 —— 这是测试台最稳妥的"打一拍脉冲"写法。
//   如果直接在 posedge 之后立刻赋值，测试台和 DUT 的 always @(posedge clk)
//   会竞争同一个时刻，DUT 可能采到旧值（exec=0），请求就被漏掉了。
task send_req(input kind);
    begin
        @(negedge clk);            // 等一个下降沿（此刻时钟为低）
        rh_wl = kind;              // 先定好读写方向（阻塞赋值，立即生效）
        exec  = 1'b1;              // 再把 exec 拉高
        @(negedge clk);            // 等下一个下降沿（中间跨过一个 posedge）
        exec  = 1'b0;              // 拉低 → 形成单周期脉冲
    end
endtask

//----------------- 测量任务：测 flag_w 高电平持续了几拍 -----------------
// 目的：验证"时钟展宽"是否真的把信号拉长了约 130 拍。
// 【重要教训】为什么不能把 flag_w 作为 task 的 input 传进来？
//   Verilog task 的 input 参数是"调用那一刻的值拷贝（快照）"，
//   传进来之后它就是固定的 0 或 1，不会再跟着信号变化。
//   如果写成 measure(flag_w)，task 里的 while(flag_w===1) 会永远成立 → 死循环。
//   所以这里直接引用全局信号 flag_w，task 里看到的才是"实时值"。
// wait(条件) 与 @(事件) 的区别：
//   wait(flag_w===1)：电平敏感，条件一满足立刻继续往下走；
//   @(posedge clk)：事件敏感，必须等到下一个上升沿才继续。
// 测量原理：flag 为高的期间，每遇到一个 posedge 就 +1，直到 flag 变低。
task measure_high_w(output integer cycles);
    begin
        cycles = 0;                                // 拍数清零
        wait (flag_w === 1'b1);                    // 等 flag_w 拉高
        while (flag_w === 1'b1) begin              // 只要还是高：
            @(posedge clk);                        //   等一个上升沿
            cycles = cycles + 1;                   //   记 1 拍
        end
        // 循环退出时，cycles 里就是高电平持续的总拍数
    end
endtask

//----------------- 测量任务：测 flag_r 高电平持续了几拍（同上） -----------------
task measure_high_r(output integer cycles);
    begin
        cycles = 0;
        wait (flag_r === 1'b1);
        while (flag_r === 1'b1) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
    end
endtask

//----------------- 检查任务 3：检查展宽宽度 -----------------
// 把测到的拍数 w 和 [MIN_W, MAX_W] 比较。
// 为什么不要求严格等于某个数？因为测量起点有 ±1~2 拍的边界误差
// （实测约 133 拍，设计目标约 131 拍），所以给一个容差范围：
//   - 小于 120：说明"没展宽/展宽太短"（计数器或译码逻辑坏了）；
//   - 大于 150：说明"卡死一直拉高"（撤销逻辑坏了）。
task check_width(input [8*32-1:0] name, input integer w);
    begin
        if (w < MIN_W || w > MAX_W) begin
            $display("[%0t] FAIL: %0s 展宽 %0d 拍，不在 [%0d, %0d] 范围内",
                     $time, name, w, MIN_W, MAX_W);
            errors = errors + 1;
        end
        else
            $display("[%0t] OK  : %0s 展宽 %0d 拍（期望约 131 拍）", $time, name, w);
    end
endtask

//==================== 主测试流程 ====================
// initial 块：仿真开始（t=0）时执行，按顺序跑完所有测试用例。
// 里面用的是阻塞赋值 =（立即生效），因为 tb 是"激励发生器"，
// 不需要像硬件那样用非阻塞 <=（DUT 内部才用 <= 模拟寄存器并行更新）。
initial begin
    $dumpfile("signal_tb.vcd");    // 指定波形文件名
    $dumpvars(0, signal_tb);       // 把整个 tb（含 DUT）的所有信号都存进波形

    //---------- 1. 复位测试 ----------
    // 把 reset_l 拉低 3 个周期 → 模块执行复位逻辑；
    // 再拉高 2 个周期 → 释放复位，让信号稳定下来，然后检查初值。
    $display("\n===== 1. reset test =====");
    reset_l = 1'b0;                // 进入复位
    #(CLK_PERIOD*3);               // 保持复位 3 个时钟周期（60ns）
    reset_l = 1'b1;                // 释放复位
    #(CLK_PERIOD*2);               // 等 2 个周期，让复位后的值稳定

    // 复位后三个输出都应该是 0（低电平）
    check_low("flag_w(reset)", flag_w);
    check_low("flag_r(reset)", flag_r);
    check_low("I2C_start(reset)", I2C_start);

    //---------- 2. 空闲检查 ----------
    // 不发任何请求，等 5 个周期，确认三个输出不会自己乱动（无毛刺）。
    $display("\n===== 2. idle check =====");
    #(CLK_PERIOD*5);
    check_low("flag_w(idle)", flag_w);
    check_low("flag_r(idle)", flag_r);
    check_low("I2C_start(idle)", I2C_start);

    //---------- 3. 写请求测试 ----------
    // 发一个写请求（kind=0），预期：
    //   flag_w 拉高并展宽约 131 拍；flag_r 保持 0；I2C_start 也拉高约 131 拍。
    $display("\n===== 3. write request (rh_wl=0) =====");
    send_req(1'b0);                // 发送写请求
    wait (flag_w === 1'b1);        // 等写标志拉高（请求后约 2~3 拍）
    check_high("flag_w(write)", flag_w);       // 写标志应为高
    check_low ("flag_r(write)", flag_r);       // 读标志应为低（没发读）
    check_high("I2C_start(write)", I2C_start); // 起始信号应为高
    measure_high_w(cnt);           // 测 flag_w 高电平拍数 → 存入 cnt
    check_width("flag_w", cnt);    // 检查展宽宽度是否在合理范围
    check_low("flag_r(after_write)", flag_r);  // 写结束后读标志仍应为 0
    wait (I2C_start === 1'b0);     // 等起始信号自己回落（约 131 拍后）
    #(CLK_PERIOD);                 // 再等一拍，留出余量

    //---------- 4. 读请求测试 ----------
    // 与写请求对称：发读请求（kind=1），预期 flag_r 拉高展宽、flag_w 保持 0。
    $display("\n===== 4. read request (rh_wl=1) =====");
    send_req(1'b1);                // 发送读请求
    wait (flag_r === 1'b1);        // 等读标志拉高
    check_high("flag_r(read)", flag_r);
    check_low ("flag_w(read)", flag_w);
    check_high("I2C_start(read)", I2C_start);
    measure_high_r(cnt);           // 测 flag_r 高电平拍数
    check_width("flag_r", cnt);
    check_low("flag_w(after_read)", flag_w);
    #(CLK_PERIOD);

    //---------- 5. 连续请求测试（写后紧跟读） ----------
    // 验证：写标志还没撤掉时马上发读请求，两个标志可以同时为高，
    //       I2C_start 会被第二次 exec 重新拉高（计数器重新计时）。
    $display("\n===== 5. back-to-back (write->read) =====");
    send_req(1'b0);                // 先发写
    wait (flag_w === 1'b1);        // 等写标志拉高
    send_req(1'b1);                // 紧接着发读（写标志还没撤）
    wait (flag_r === 1'b1);        // 等读标志拉高
    check_high("flag_r(seq_read)", flag_r);    // 读标志应为高
    check_high("flag_w(seq_write)", flag_w);   // 写标志此刻仍为高
    check_high("I2C_start(seq)", I2C_start);   // 起始信号应为高
    // 等所有信号都恢复低电平（各自按自己的计数器计时结束后回落）
    wait (flag_r === 1'b0 && flag_w === 1'b0 && I2C_start === 1'b0);
    #(CLK_PERIOD);

    //---------- 6. 最终空闲检查 ----------
    // 全部操作结束后再等 10 个周期，确认信号都干净地回到低电平。
    $display("\n===== 6. final idle check =====");
    #(CLK_PERIOD*10);
    check_low("flag_w(final_idle)", flag_w);
    check_low("flag_r(final_idle)", flag_r);
    check_low("I2C_start(final_idle)", I2C_start);

    //---------- 汇总 ----------
    // errors 全程累计失败次数，等于 0 才算全部通过。
    $display("\n=====================================");
    if (errors == 0)
        $display("=========== ALL TESTS PASSED ===========");
    else
        $display("=========== %0d ERRORS FOUND ===========", errors);
    $display("=====================================");
    $finish;                       // 结束仿真
end

endmodule

    




    









