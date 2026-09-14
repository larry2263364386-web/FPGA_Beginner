`timescale      1ns/100ps


module hello_world_tb;

reg             reset_l ;
reg             clk     ;  
reg             key_0   ;
reg             key_1   ;

wire            led_0   ;
wire            led_1   ;

hello_world u_hello_world(
    .reset_l(reset_l),
    .clk(clk),
    .key_0(key_0),
    .key_1(key_1),
    .led_0(led_0),
    .led_1(led_1)
);

task automatic test_reset;
begin
    $display("\n====== TestCase1 : Reset Test ======");
    reset_l = 1'b0;
    key_0   = 1'b1;
    key_1   = 1'b1;
    #300;
    $display("Time=%0t ns | reset_l=%b, key_0=%b, key_1=%b, led_0=%b, led_1=%b",$time,reset_l,key_0,key_1,led_0,led_1);
    
    reset_l = 1'b1;
    #800;
    $display("Time=%0t ns | reset_l=%b, key_0=%b, key_1=%b, led_0=%b, led_1=%b",$time,reset_l,key_0,key_1,led_0,led_1);
    $display("====== Reset Test End ======\n");
end
endtask

task automatic test_key;
input [1:0] key_in;
begin
    $display("\n====== TestCase2 : Key Test, key_1 key_0 = %b ======", key_in);
    {key_1,key_0} = key_in;
    #600;
    $display("Time=%0t ns | key_0=%b, key_1=%b, led_0=%b, led_1=%b",$time,key_0,key_1,led_0,led_1);
end
endtask

initial begin
    clk = 1'b0;
end
always #10 clk = ~clk;

initial begin
    reset_l = 1'b1;
    key_0   = 1'b1;
    key_1   = 1'b1;
    #100;
    
    test_reset;
    test_key(2'b11);   //两键松开
    test_key(2'b10);   //key_1 按下、key_0 松开
    test_key(2'b11);
    test_key(2'b01);   //key_0 按下、key_1 松开
    test_key(2'b11);
    test_key(2'b00);   //两键同时按下
    
    #800
    $display("\n==== All Test Cases Finished ====");
    $stop;
end
endmodule      