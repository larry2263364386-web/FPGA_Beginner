`timescale      1ns/100ps


module counter_seg_tb;

reg             clk         ;
reg             reset_l     ;
reg     [13:0]  data        ;

wire    [3:0]   seg_s       ;
wire    [7:0]   seg         ;

counter_seg     u_counter_seg(
    .clk         ( clk       ),
    .reset_l     ( reset_l   ),
    .data        ( data      ),
    .seg_s       ( seg_s     ),
    .seg         ( seg       )
);

task automatic test_reset;
begin
    $display("\n====== TestCase1 : Reset Test ======");
    reset_l <= 1'b0;
    data    <= 14'd1234;
    #300; 
    $display("Time=%0t ns | reset_l=%b, seg_s=%b, seg=%h",$time,reset_l,seg_s,seg);
    
    reset_l <= 1'b1;
    #1000;
    $display("Time=%0t ns | reset_l=%b, seg_s=%b, seg=%h",$time,reset_l,seg_s,seg);
    $display("====== Reset Test End ======\n");
end
endtask


task automatic test_scan;
input [13:0] test_data;
begin
    $display("\n====== TestCase2 : Scan Test, Input Number = %0d ======", test_data);
    data <= test_data;
    #3000;
    $display("Time=%0t ns | seg_s=%b, seg=%h",$time,seg_s,seg);
end
endtask

initial begin
    clk     <=1'b0;
end

always #10 clk <= ~clk;


initial begin
    reset_l <= 1'b1;
    data    <= 14'd0;
    #100;
    
    test_reset;
    test_scan(14'd1234);
    test_scan(14'd9876);
    test_scan(14'd0000);
    
    #1000;
    $display("/n==== All Test Cases Finished ====");
    $stop;
end

endmodule