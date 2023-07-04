`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/03/2023 11:15:16 PM
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top(

    );
    
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire [7:0]dout;
    reg enable = 1'b0;
    wire SCK;
    wire CS_n;
    wire MOSI;
    reg MISO = 1'b0;
         
    top udt(.*);
    
    always #1 clk = ~clk;
    
    initial begin
        #2 rst_n = 1'b1;
        #2 enable = 1'b1;
        #10000 $stop; 
    end
    
endmodule
