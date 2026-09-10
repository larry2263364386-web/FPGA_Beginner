`timescale      1ns/100ps


module hello_world_tb;

reg             reset_l ;
reg             clk     ;  
reg             key_0   ;
reg             key_1   ;
wire            led_0   ;
wire            led_1   ;

initial begin
    reset_l     <= 1'b0;
    clk         <= 1'b0;
    key_0       <= 1'b1;
    key_1       <= 1'b1;
    #200
    reset_l     <= 1'b1;  
    
    #100
    key_0       <= 1'b0;
    #100
    key_0       <= 1'b1;
    
    #100
    key_1       <= 1'b0;
    #100
    key_1       <= 1'b1;

end

always #10 clk  <= ~clk;

hello_world     u_hello_world(
    .clk         ( clk       ),
    .reset_l     ( reset_l   ),
    .key_0       ( key_0     ),
    .key_1       ( key_1     ),
    .led_0       ( led_0     ),
    .led_1       ( led_1     )  
);

endmodule      