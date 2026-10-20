`timescale 1ns / 1ns
module clock_frequency_divider_tb;

reg                     reset_l;
reg                     clk_in;
reg      [8:0]          div_M;
reg      [0:0]          div_N;
wire                    clk_out;

clock_frequency_divider uut(
    .reset_l    (reset_l),
    .clk_in     (clk_in),
    .div_M      (div_M),
    .div_N      (div_N),
    .clk_out    (clk_out)
);

initial begin
    clk_in = 1'b0;
    forever #10 clk_in = ~clk_in;
end

initial begin
    reset_l = 1'b0;
    div_M   = 9'd10;
    div_N   = 1'd1;
    #20;
    
    reset_l = 1'b1;
    #1000;
    
    div_M = 9'd8;
    div_N = 1'd1;
    #800;
    
    $stop;
end

endmodule
