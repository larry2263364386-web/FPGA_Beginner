// **************************** Declaration ****************************
// File name:        signal.v
// Author:           Larry
// Date:             2026-10-20
// Version Number:   1.0
// Abstract:         I2C 读/写请求锁存 + 脉宽扩展（时钟展宽）
//                   exec 单拍脉冲 → 展宽成约 131 周期的 flag_w/flag_r 与 I2C_start
// Board:            Cyclone IV E  EP4CE10F17C8
// Clock:            50 MHz (PIN_E1)
//
// Modification history:(including time, version, author and abstract)
// 2026-10-20   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
`timescale 1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 模块功能：I2C 读/写请求锁存 + 时钟展宽（脉宽扩展）
//   输入 exec（执行脉冲）+ rh_wl（读/写选择，0=写 1=读），输出：
//   · flag_w：写标志，exec 写脉冲触发后展宽约 131 个时钟周期
//   · flag_r：读标志，exec 读脉冲触发后展宽约 131 个时钟周期
//   · I2C_start：I2C 起始信号，exec 触发后展宽约 131 个时钟周期
//
//   本质是「单拍脉冲 → 长脉冲」的脉宽扩展器，展宽周期由 cnt>130 决定。
//   本模块无引脚绑定，主要配合 ModelSim / SignalTap 做时序验证。
//
// 学习要点：
//   1. 三段式状态机拆解：先锁存请求（signal 状态），再译码（signal_r/w），
//      再各自展宽（cnt_r / cnt_w），职责单一、好调
//   2. 计数器展宽：flag 拉高后计数器从 0 数到 130 再清零，得到固定脉宽
//   3. 注意寄存器 signal 与模块同名——合法但易混，起名应避免
//──────────────────────────────────────────────────────────────────────

module signal(
    input           clk,
    input           reset_l,
    input           exec,
    input           rh_wl,
    output  reg     flag_w,
    output  reg     flag_r,
    output  reg     I2C_start
);

reg [1:0]   signal;      //请求状态：00 空闲 / 01 写 / 10 读（与模块同名，注意区分）
reg         signal_r;    //读请求译码（signal==2'b10 时拉高）
reg         signal_w;    //写请求译码（signal==2'b01 时拉高）

//第一段：锁存请求类型。exec 高时按 rh_wl 锁存写(01)/读(10)，否则回空闲
always @(posedge clk or negedge reset_l) begin
    if(!reset_l) begin
        signal <= 2'b00;
    end
    else if((exec == 1'b1) && (rh_wl == 1'b0)) begin
        signal <= 2'b01;        //写请求
    end
    else if((exec == 1'b1) && (rh_wl == 1'b1)) begin
        signal <= 2'b10;        //读请求
    end
    else begin
        signal <= 2'b00;        //空闲
    end
end

//第二段：状态译码，得到一对互斥的读写标志
always @(posedge clk or negedge reset_l) begin
    if (!reset_l) begin
        signal_r <= 1'b0;
        signal_w <= 1'b0;
    end
    else begin
        case (signal)
            2'b00: begin
                signal_r <= 1'b0;
                signal_w <= 1'b0;
            end
            2'b01: begin
                signal_r <= 1'b0;
                signal_w <= 1'b1;   //写：只拉 flag_w
            end
            2'b10: begin
                signal_r <= 1'b1;   //读：只拉 flag_r
                signal_w <= 1'b0;
            end
            default: begin
                signal_r <= 1'b0;
                signal_w <= 1'b0;
            end
        endcase
    end
end

reg [7:0]   cnt_r;

//第三段（读）：signal_r 触发后，flag_r 展宽约 131 个周期（cnt 0→130 再清零）
always @(posedge clk or negedge reset_l) begin
    if (!reset_l) begin
        cnt_r  <= 8'b0;
        flag_r <= 1'b0;
    end
    else begin
        cnt_r <= cnt_r + 1'b1;
        if (signal_r) begin
            cnt_r   <= 8'b0;        //触发沿：重新开始计展宽
            flag_r  <= 1'b1;
        end
        if (cnt_r > 8'd130) begin
            flag_r  <= 1'b0;        //展宽结束：拉低
            cnt_r   <= 8'b0;
        end
    end
end

reg [7:0]cnt_w;

//第三段（写）：signal_w 触发后，flag_w 展宽约 131 个周期，逻辑同上
always @(posedge clk or negedge reset_l) begin
    if (!reset_l) begin
        cnt_w  <= 8'b0;
        flag_w <= 1'b0;
    end
    else begin
        cnt_w <= cnt_w + 1'b1;
        if (signal_w) begin
            cnt_w   <= 8'b0;
            flag_w  <= 1'b1;
        end
        if (cnt_w > 8'd130) begin
            flag_w  <= 1'b0;
            cnt_w   <= 8'b0;
        end
    end
end

reg [7:0] I2C_start_cnt;

//I2C_start：exec 触发后同样展宽约 131 个周期
always @(posedge clk or negedge reset_l) begin
    if (!reset_l) begin
        I2C_start <= 1'b0;
        I2C_start_cnt <= 8'b0;
    end
    else begin
        I2C_start_cnt <= I2C_start_cnt + 1'b1;
        if (exec) begin
            I2C_start_cnt <= 8'b0;
            I2C_start <= exec;      //直接用 exec 触发起始信号
        end
        if(I2C_start_cnt > 8'd130) begin
            I2C_start <= 1'b0;
            I2C_start_cnt <= 8'b0;
        end
    end
end


endmodule
