`timescale 1ns/1ns
module dynamic_delay_tb;

parameter delay_width = 4;
parameter data_width  = 8;
parameter ram_type    = "registers";

reg                     clk;
reg                     reset_l;
reg                     clk_en;
reg  [delay_width-1:0]  delay_cycles;
reg  [data_width-1:0]   data_in;
wire [data_width-1:0]   data_out;

dynamic_delay #(
    .delay_width(delay_width),
    .data_width (data_width),
    .ram_type   (ram_type)
) u_dut (
    .clk         (clk),
    .reset_l     (reset_l),
    .clk_en      (clk_en),
    .delay_cycles(delay_cycles),
    .data_in     (data_in),
    .data_out    (data_out)
);

initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

initial begin
    reset_l      = 0;
    clk_en       = 0;
    delay_cycles = 10;
    data_in      = 0;
    
    #20;
    reset_l = 1;
    
    #20;
    clk_en = 1;
    
    repeat(15) begin
        #20 data_in = data_in + 1'b1;
    end
    
    #20;
    delay_cycles = 5;
    
    repeat(15) begin
        #20 data_in = data_in + 1'b1;
    end
    
    #200;
    $stop;
end

initial begin
    $monitor("time=%0t | reset_l=%b | clk_en=%b | delay=%d | data_in=%d | data_out=%d",
             $time, reset_l, clk_en, delay_cycles, data_in, data_out);
end

endmodule
