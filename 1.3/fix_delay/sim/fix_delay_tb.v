`timescale 1ns/1ns
module fix_delay_tb;
parameter delay_cycles = 10;
parameter data_width   = 8;
reg clk;
reg reset_l;
reg clk_en;
reg  [data_width-1:0] data_in;
wire [data_width-1:0] data_out;
fix_delay #(
    .delay_cycles(delay_cycles),
    .data_width(data_width),
    .ram_type("registers")
) u_fix_delay (
    .clk(clk),
    .reset_l(reset_l),
    .clk_en(clk_en),
    .data_in(data_in),
    .data_out(data_out)
);
initial begin
    clk = 0;
    forever #10 clk = ~clk;
end
initial begin
    reset_l = 0;
    clk_en  = 0;
    data_in = 0;
    #20;
    reset_l = 1;
    #20;
    clk_en = 1;
    data_in = 8'd1;   #20;
    data_in = 8'd2;   #20;
    data_in = 8'd3;   #20;
    data_in = 8'd4;   #20;
    data_in = 8'd5;   #20;
    data_in = 8'd6;   #20;
    data_in = 8'd7;   #20;
    data_in = 8'd8;   #20;
    data_in = 8'd9;   #20;
    data_in = 8'd10;  #20;
    data_in = 8'd11;  #20;
    data_in = 8'd12;  #20;
    data_in = 8'd13;  #20;
    data_in = 8'd14;  #20;
    data_in = 8'd15;  #20;
    data_in = 8'd16;  #20;
    #300;
    $stop;
end
initial begin
    $monitor("time=%0t, reset_l=%b, clk_en=%b, data_in=%d, data_out=%d",$time,reset_l,clk_en,data_in,data_out);
end
endmodule
