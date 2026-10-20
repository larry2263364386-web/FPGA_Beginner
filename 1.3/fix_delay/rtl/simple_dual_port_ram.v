// **************************** Declaration ****************************
// File name:        simple_dual_port_ram.v
// Author:           Larry
// Date:             2026-10-20
// Version Number:   1.0
// Abstract:         简单双口 RAM：一个写口(A) + 一个读口(B)
//                   按 ram_type 选块RAM(M9K)或寄存器实现，供延迟线使用
// Board:            Cyclone IV E  EP4CE10F17C8
// Clock:            50 MHz (PIN_E1)
//
// Modification history:(including time, version, author and abstract)
// 2026-10-20   version 1.0   Larry
// Abstract: Initial
// **************************** end ****************************
`timescale 1ns/100ps

//──────────────────────────────────────────────────────────────────────
// 模块功能：简单双口 RAM（simple dual-port RAM）
//   一个写端口（a*）+ 一个读端口（b*），读写可同时、各自独立时钟使能。
//   顶层 simple_dual_port_ram 是「分发器」，按 ram_type 用 generate 选实现：
//   · "M9K"/"BLOCK_RAM"          → simple_dual_port_ram_b（综合成块 RAM）
//   · "registers"/"distributed"  → simple_dual_port_ram_r（综合成寄存器阵列）
//
// 学习要点：
//   1. 双口 RAM 分两类：真双口(读写都双口) vs 简单双口(一读一写)，本模块是后者
//   2. syn_ramstyle 综合属性强制 Quartus 用寄存器 / M9K 实现，避免它自己乱选
//   3. 读端口带一级输出寄存器（brd_data <= mem_array[...]），读延迟 1 拍
//──────────────────────────────────────────────────────────────────────

module simple_dual_port_ram(
    aclk,
    aclk_en,
    awr_en,
    awr_addr,
    awr_data,
    bclk,
    bclk_en,
    brd_addr,
    brd_data
);
parameter
    addr_width = 4,
    data_width = 8,
    ram_type = "registers";

input                   aclk;       //写口时钟
input                   aclk_en;    //写口时钟使能
input                   awr_en;     //写使能
input [addr_width-1:0]  awr_addr;   //写地址
input [data_width-1:0]  awr_data;   //写数据
input                   bclk;       //读口时钟
input                   bclk_en;    //读口时钟使能
input [addr_width-1:0]  brd_addr;   //读地址
output [data_width-1:0] brd_data;   //读数据

//按 ram_type 选块 RAM 实现
generate
    if (ram_type == "M9K" || ram_type == "BLOCK_RAM") begin : M9K_RAM_Gen
        simple_dual_port_ram_b #(
            .addr_width(addr_width),
            .data_width(data_width)
        )
        u_ram_b(
            .aclk       (aclk),
            .aclk_en    (aclk_en),
            .awr_en     (awr_en),
            .awr_addr   (awr_addr),
            .awr_data   (awr_data),
            .bclk       (bclk),
            .bclk_en    (bclk_en),
            .brd_addr   (brd_addr),
            .brd_data   (brd_data)
        );
    end
endgenerate

//按 ram_type 选寄存器实现
generate
    if (ram_type  == "registers" || ram_type  == "distributed") begin : Register_RAM_Gen
        simple_dual_port_ram_r # (
            .addr_width(addr_width),
            .data_width(data_width)
        )
        u_ram_r(
            .aclk    (aclk),
            .aclk_en (aclk_en),
            .awr_en  (awr_en),
            .awr_addr(awr_addr),
            .awr_data(awr_data),
            .bclk    (bclk),
            .bclk_en (bclk_en),
            .brd_addr(brd_addr),
            .brd_data(brd_data)
        );
	end
endgenerate
endmodule

//──────────────────────────────────────────────────────────────────────
// 寄存器实现（syn_ramstyle = "registers"，用触发器阵列搭 RAM）
// 适合小容量延迟线；大容量会吃掉大量逻辑资源
//──────────────────────────────────────────────────────────────────────
module simple_dual_port_ram_r(
    aclk,
    aclk_en,
    awr_en,
    awr_addr,
    awr_data,
    bclk,
    bclk_en,
    brd_addr,
    brd_data
);
parameter
    addr_width = 4,
    data_width = 8;
input                           aclk;
input                           aclk_en;
input                           awr_en;
input [addr_width-1:0]          awr_addr;
input [data_width-1:0]          awr_data;
input                           bclk;
input                           bclk_en;
input [addr_width-1:0]          brd_addr;
output reg [data_width-1:0]     brd_data;
reg [data_width-1:0] mem_array [2**addr_width-1:0] /* synthesis syn_ramstyle = "registers" */;

always @ (posedge aclk)
    begin
        if (aclk_en == 1'b1) begin
            if (awr_en == 1'b1) begin
                mem_array[awr_addr] <= awr_data;     //写端口：使能时写入
            end
        end
    end

always @(posedge bclk)
    begin
        if (bclk_en == 1'b1) begin
            brd_data <= mem_array[brd_addr];         //读端口：使能时读出（打 1 拍）
        end
    end
endmodule

//──────────────────────────────────────────────────────────────────────
// 块 RAM 实现（syn_ramstyle = "M9K"，综合到片内 M9K 存储块）
// 容量大、省逻辑资源，但读写同样带 1 拍寄存器延迟
//──────────────────────────────────────────────────────────────────────
module simple_dual_port_ram_b(
    aclk,
    aclk_en,
    awr_en,
    awr_addr,
    awr_data,
    bclk,
    bclk_en,
    brd_addr,
    brd_data
);
parameter
    addr_width = 4,
    data_width = 8;
input                       aclk;
input                       aclk_en;
input                       awr_en;
input [addr_width-1:0]      awr_addr;
input [data_width-1:0]      awr_data;
input                       bclk;
input                       bclk_en;
input [addr_width-1:0]      brd_addr;
output reg [data_width-1:0] brd_data;
reg [data_width-1:0] mem_array [2**addr_width-1:0] /* synthesis syn_ramstyle = "M9K" */;

always @ (posedge aclk)
    begin
		if (aclk_en == 1'b1) begin
			if (awr_en == 1'b1) begin
					mem_array[awr_addr] <= awr_data;
			end
		end
    end
always @ (posedge bclk)
    begin
		if (bclk_en == 1'b1) begin
			 brd_data	<= mem_array[brd_addr];
		end
    end
endmodule
