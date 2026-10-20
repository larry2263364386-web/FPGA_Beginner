`timescale 1ns / 1ps
//==============================================================================
// 测试平台（Testbench）：sop_eop_gen_tb
// 被测模块（DUT）：sop_eop_gen —— 包起始(SOP)/包结束(EOP)指示信号生成器
//------------------------------------------------------------------------------
// 【验证内容】
//   1. 复位后所有输出为 0；
//   2. 空闲（i_en=0）时输出保持 0，无毛刺；
//   3. 单拍包：SOP 在（延迟一拍后的）唯一有效拍上，且 SOP 与 EOP 同拍出现；
//   4. 多拍包：SOP 只在第一拍、EOP 只在最后一拍、数据整体延迟一拍且对齐；
//   5. 错误在最后一拍：EOP 处 o_err=1（会报错）；
//   6. 错误在中间拍：EOP 处 o_err=0（不报错——本设计只采信最后一拍的 i_err）；
//   7. clk_en=0：寄存器冻结，等效"跳过这一拍"；
//   8. 全部结束后回到干净的空闲状态。
//
// 【本 tb 的检查时机（关键，和 signal_tb 不同！）】
//   激励仍在 negedge 改变（保证 posedge 采到稳定值），但要注意：
//   - o_en / o_data / o_sop 是寄存器输出 → 在 posedge 之后 1ns 检查；
//   - o_eop / o_err 是"看当前 i_en"的组合输出：
//       o_eop = ~i_en & i_en_d0
//     i_en 在 negedge 拉低后、下一个 posedge 之前，i_en_d0 仍保持 1
//     —— 这半个周期就是 EOP 窗口，在 negedge+1ns 处检查。
//   真实系统里上游用寄存器打拍输出 i_en（posedge 后变化），
//   EOP 会是完整一拍的脉冲，并且与最后一个有效数据拍重合
//  （EOP 那一拍 o_en=1、o_data=最后一个数据 —— 类似 AXI 的 tlast）。
//
// 运行方式（iverilog）：
//   iverilog -g2005 -o sim sop_eop_gen.v sop_eop_gen_tb.v && vvp sim
// ModelSim：do sop_eop_gen_tb.do
//
// 注意：$display 输出全部用 ASCII 字符，避免 ModelSim 控制台中文乱码。
//==============================================================================
module sop_eop_gen_tb;

//----------------- 常量 -----------------
localparam CLK_PERIOD = 20;         // 时钟周期 20ns（50MHz）
localparam HALF       = CLK_PERIOD/2;

//----------------- 激励信号（reg：tb 驱动） -----------------
reg        clk     = 1'b0;          // 时钟
reg        clk_en  = 1'b1;          // 时钟使能（默认常开，测试 7 再拉低）
reg        reset_l = 1'b0;          // 低有效复位，初始处于复位态
reg        i_en    = 1'b0;          // 输入有效标志
reg        i_err   = 1'b0;          // 输入错误标志
reg  [7:0] i_data  = 8'h00;         // 输入数据

//----------------- DUT 输出（wire：DUT 驱动） -----------------
wire       o_sop;                   // 包起始
wire       o_en;                    // 延迟一拍的有效标志
wire [7:0] o_data;                  // 延迟一拍的数据
wire       o_eop;                   // 包结束
wire       o_err;                   // 包尾错误

integer    errors = 0;              // 错误计数

//----------------- 例化 DUT -----------------
sop_eop_gen u_dut(
    .clk    (clk),
    .clk_en (clk_en),
    .reset_l(reset_l),
    .i_en   (i_en),
    .i_err  (i_err),
    .i_data (i_data),
    .o_sop  (o_sop),
    .o_en   (o_en),
    .o_data (o_data),
    .o_eop  (o_eop),
    .o_err  (o_err)
);

//----------------- 时钟生成 -----------------
always #HALF clk = ~clk;

//----------------- 超时看门狗 -----------------
initial begin
    #100_000;
    $display("[%0t] TIMEOUT: test hung, some signal did not change", $time);
    $finish;
end

//==============================================================================
// 检查任务（全部用 !== 全等比较，连 X/Z 一起抓）
//==============================================================================
task check_low(input [8*32-1:0] name, input val);
    begin
        if (val !== 1'b0) begin
            $display("[%0t] FAIL: %0s expect 0, got %b", $time, name, val);
            errors = errors + 1;
        end
        else
            $display("[%0t] OK  : %0s = 0", $time, name);
    end
endtask

task check_high(input [8*32-1:0] name, input val);
    begin
        if (val !== 1'b1) begin
            $display("[%0t] FAIL: %0s expect 1, got %b", $time, name, val);
            errors = errors + 1;
        end
        else
            $display("[%0t] OK  : %0s = 1", $time, name);
    end
endtask

// 8 位数据比对：打印期望值和实际值
task check_data(input [8*32-1:0] name, input [7:0] exp, input [7:0] val);
    begin
        if (val !== exp) begin
            $display("[%0t] FAIL: %0s expect %02h, got %02h",
                     $time, name, exp, val);
            errors = errors + 1;
        end
        else
            $display("[%0t] OK  : %0s = %02h", $time, name, val);
    end
endtask

//==============================================================================
// 激励任务：驱动一拍输入
//   在 negedge 改变（时钟低电平期间），中间的 posedge 一定能采到稳定值。
//   一拍的有效窗口 = [本 negedge, 下一 negedge]。
//==============================================================================
task drive_beat(input v, input [7:0] d, input e);
    begin
        @(negedge clk);
        i_en   = v;
        i_data = d;
        i_err  = e;
    end
endtask

//==============================================================================
// 检查任务：EOP 窗口检查
//   调用时机：drive_beat(0,...) 之后立刻 #1（negedge+1ns，此时：
//     i_en     = 0（刚拉低）
//     i_en_d0  = 1（上一拍寄存的最后有效拍，寄存器还没更新）
//   组合输出在此半周期内成立：
//     o_eop = ~i_en & i_en_d0 = 1
//     o_err = o_eop & i_err_d0（i_err_d0 = 最后有效拍的 i_err）
//   同时寄存器输出仍保持最后有效拍的值：o_en=1、o_data=最后数据。
//==============================================================================
task check_eop_window(input [8*32-1:0] tag,
                      input exp_eop, input exp_err,
                      input [7:0] exp_last_data);
    begin
        if (exp_eop === 1'b1) begin
            // EOP 拍：o_en 仍为 1、数据仍是最后一拍的数据（EOP 与数据重合）
            check_high ({tag,": o_en(last) "}, o_en);
            check_data ({tag,": o_data(last)"}, exp_last_data, o_data);
        end
        // EOP / ERR 电平检查
        if (exp_eop === 1'b1) check_high ({tag,": o_eop"}, o_eop);
        else                  check_low  ({tag,": o_eop"}, o_eop);
        if (exp_err === 1'b1) check_high ({tag,": o_err"}, o_err);
        else                  check_low  ({tag,": o_err"}, o_err);
    end
endtask

//==================== 主测试流程 ====================
initial begin
    $dumpfile("sop_eop_gen_tb.vcd");
    $dumpvars(0, sop_eop_gen_tb);

    //---------- 1. 复位测试 ----------
    $display("\n===== 1. reset test =====");
    reset_l = 1'b0;
    #(CLK_PERIOD*3);
    reset_l = 1'b1;
    #(CLK_PERIOD*2);
    check_low ("o_en(reset)",  o_en);
    check_low ("o_sop(reset)", o_sop);
    check_low ("o_eop(reset)", o_eop);
    check_low ("o_err(reset)", o_err);
    check_data("o_data(reset)", 8'h00, o_data);

    //---------- 2. 空闲检查 ----------
    $display("\n===== 2. idle check =====");
    #(CLK_PERIOD*5);
    check_low ("o_en(idle)",  o_en);
    check_low ("o_sop(idle)", o_sop);
    check_low ("o_eop(idle)", o_eop);
    check_low ("o_err(idle)", o_err);

    //---------- 3. 单拍包测试 ----------
    // 包只有 1 拍有效数据：SOP 在这一拍，EOP 也回到这一拍（同拍重合）
    $display("\n===== 3. single-beat packet =====");
    drive_beat(1'b1, 8'hA5, 1'b0);       // 唯一一拍数据 A5
    @(posedge clk) #1;                   // posedge 后 1ns：本拍输出已寄存
    check_high("o_en(single)",  o_en);
    check_data("o_data(single)", 8'hA5, o_data);
    check_high("o_sop(single)", o_sop);  // 包头
    check_low ("o_eop(single)", o_eop);  // EOP 还没来
    check_low ("o_err(single)", o_err);

    drive_beat(1'b0, 8'h00, 1'b0);       // i_en 拉低 → 进入 EOP 窗口
    #1;                                   // negedge+1ns：组合输出窗口
    check_eop_window("single_end", 1'b1, 1'b0, 8'hA5);
    check_high("o_sop(single_end)", o_sop); // 单拍包：SOP 与 EOP 同拍！

    @(posedge clk) #1;                   // 下一拍：一切归零
    check_low ("o_en(after_single)",  o_en);
    check_low ("o_sop(after_single)", o_sop);
    check_low ("o_eop(after_single)", o_eop);
    check_low ("o_err(after_single)", o_err);
    #(CLK_PERIOD);

    //---------- 4. 多拍包测试（4 拍，无错误） ------                       ----
    // 验证：SOP 只在第一拍；数据逐拍延迟一拍；EOP 只在最后一拍
    $display("\n===== 4. 4-beat packet =====");
    drive_beat(1'b1, 8'h10, 1'b0);       // 第 1 拍（包头）
    @(posedge clk) #1;
    check_high("o_en(p0)",  o_en);
    check_data("o_data(p0)", 8'h10, o_data);
    check_high("o_sop(p0)", o_sop);      // 只有第一拍有 SOP
    check_low ("o_eop(p0)", o_eop);

    drive_beat(1'b1, 8'h20, 1'b0);       // 第 2 拍
    @(posedge clk) #1;
    check_high("o_en(p1)",  o_en);
    check_data("o_data(p1)", 8'h20, o_data);
    check_low ("o_sop(p1)", o_sop);
    check_low ("o_eop(p1)", o_eop);

    drive_beat(1'b1, 8'h30, 1'b0);       // 第 3 拍
    @(posedge clk) #1;
    check_high("o_en(p2)",  o_en);
    check_data("o_data(p2)", 8'h30, o_data);
    check_low ("o_sop(p2)", o_sop);
    check_low ("o_eop(p2)", o_eop);

    drive_beat(1'b1, 8'h40, 1'b0);       // 第 4 拍（最后一拍有效数据）
    @(posedge clk) #1;
    check_high("o_en(p3)",  o_en);
    check_data("o_data(p3)", 8'h40, o_data);
    check_low ("o_sop(p3)", o_sop);
    check_low ("o_eop(p3)", o_eop);
    check_low ("o_err(p3)", o_err);

    drive_beat(1'b0, 8'h00, 1'b0);       // 拉低 → EOP 窗口
    #1;
    check_eop_window("p_end", 1'b1, 1'b0, 8'h40);
    check_low("o_sop(p_end)", o_sop);    // 多拍包：EOP 拍上 SOP=0

    @(posedge clk) #1;
    check_low ("o_en(after_p)",  o_en);
    check_low ("o_sop(after_p)", o_sop);
    check_low ("o_eop(after_p)", o_eop);
    #(CLK_PERIOD);

    //---------- 5. 错误在最后一拍的包（3 拍） ----------
    // 预期：EOP 处 o_err=1（错误在最后一拍 → 会被报告）
    $display("\n===== 5. error on last beat =====");
    drive_beat(1'b1, 8'hD1, 1'b0);
    @(posedge clk) #1;
    check_high("o_sop(e0)", o_sop);

    drive_beat(1'b1, 8'hD2, 1'b0);
    @(posedge clk) #1;
    check_low("o_sop(e1)", o_sop);

    drive_beat(1'b1, 8'hD3, 1'b1);       // 最后一拍带错误标志
    @(posedge clk) #1;
    check_data("o_data(e2)", 8'hD3, o_data);
    check_low ("o_err(e2)", o_err);      // 此拍 o_eop=0，o_err 还不出现

    drive_beat(1'b0, 8'h00, 1'b0);       // EOP 窗口
    #1;
    check_eop_window("err_last", 1'b1, 1'b1, 8'hD3);  // EOP=1 且 ERR=1！

    @(posedge clk) #1;
    check_low ("o_err(after_err)", o_err);
    check_low ("o_en(after_err)",  o_en);
    #(CLK_PERIOD);

    //---------- 6. 错误在中间拍的包（3 拍） ----------
    // 预期：EOP 处 o_err=0（中间拍的错误不会被报告——本设计只看最后一拍）
    $display("\n===== 6. error on middle beat (NOT reported) =====");
    drive_beat(1'b1, 8'hE1, 1'b0);
    @(posedge clk) #1;
    check_high("o_sop(m0)", o_sop);

    drive_beat(1'b1, 8'hE2, 1'b1);       // 中间拍带错误标志
    @(posedge clk) #1;
    check_low ("o_err(m1)", o_err);      // 包中间不报错

    drive_beat(1'b1, 8'hE3, 1'b0);       // 最后一拍无错误
    @(posedge clk) #1;
    check_low ("o_err(m2)", o_err);

    drive_beat(1'b0, 8'h00, 1'b0);       // EOP 窗口
    #1;
    check_eop_window("err_mid", 1'b1, 1'b0, 8'hE3);   // EOP=1 但 ERR=0

    @(posedge clk) #1;
    check_low ("o_err(after_m)", o_err);
    #(CLK_PERIOD);

    //---------- 7. clk_en 测试（寄存器冻结） ----------
    // 流程：使能拍(存0x11) → 禁能拍(换数据0x22但不更新) → 恢复使能(存0x22) → 收包
    // 注意：禁能期间 i_en 保持 1 不动——模拟真实上游
    //  （数据速率低于时钟时，上游会把数据保持到下一个使能拍）
    $display("\n===== 7. clk_en freeze test =====");
    @(negedge clk);
    clk_en = 1'b1;                       // 确保使能（初始就是 1）
    i_en   = 1'b1;
    i_data = 8'h11;
    i_err  = 1'b0;
    @(posedge clk) #1;                   // 使能拍：寄存 0x11
    check_high("o_en(ce0)",   o_en);
    check_data("o_data(ce0)", 8'h11, o_data);
    check_high("o_sop(ce0)",  o_sop);    // 新包 → SOP

    @(negedge clk);
    clk_en = 1'b0;                       // 禁能！
    i_data = 8'h22;                      // 换新数据（i_en 保持 1）
    @(posedge clk) #1;                   // 这一拍被"跳过"：寄存器冻结
    check_high("o_en(ce_frozen)",   o_en);
    check_data("o_data(ce_frozen)", 8'h11, o_data);  // 仍是旧值 0x11！
    check_high("o_sop(ce_frozen)",  o_sop);          // SOP 也保持

    @(negedge clk);
    clk_en = 1'b1;                       // 恢复使能（i_data 仍为 0x22）
    @(posedge clk) #1;                   // 恢复更新：寄存 0x22
    check_high("o_en(ce_resume)",   o_en);
    check_data("o_data(ce_resume)", 8'h22, o_data);  // 现在才是 0x22
    check_low ("o_sop(ce_resume)",  o_sop);          // i_en 没变化 → 无新 SOP

    drive_beat(1'b0, 8'h00, 1'b0);       // 收包 → EOP 窗口
    #1;
    check_eop_window("ce_end", 1'b1, 1'b0, 8'h22);

    @(posedge clk) #1;
    check_low ("o_en(after_ce)",  o_en);
    check_low ("o_eop(after_ce)", o_eop);
    #(CLK_PERIOD);

    //---------- 8. 最终空闲检查 ----------
    $display("\n===== 8. final idle check =====");
    #(CLK_PERIOD*10);
    check_low ("o_en(final_idle)",  o_en);
    check_low ("o_sop(final_idle)", o_sop);
    check_low ("o_eop(final_idle)", o_eop);
    check_low ("o_err(final_idle)", o_err);

    //---------- 汇总 ----------
    $display("\n=====================================");
    if (errors == 0)
        $display("=========== ALL TESTS PASSED ===========");
    else
        $display("=========== %0d ERRORS FOUND ===========", errors);
    $display("=====================================");
    $finish;
end

endmodule
























