`timescale      1ns/100ps


module counter_seg_tb;

reg             clk         ;
reg             reset_l     ;
wire    [3:0]   seg_s       ;
wire    [7:0]   seg         ;

initial begin
    clk     <= 1'b0;
    reset_l         <= 1'b0;
    #200
    reset_l     <= 1'b1;
end

always #10 clk  <= ~clk;

counter_seg     u_counter_seg(
    .clk         ( clk       ),
    .reset_l     ( reset_l   ),
    .seg_s       ( seg_s     ),
    .seg         ( seg       )
);

endmodule