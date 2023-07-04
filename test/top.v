`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/03/2023 10:50:05 PM
// Design Name: 
// Module Name: top
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


module top(
        input clk,
        input rst_n,
        output [7:0]dout,
        input enable,
        output SCK,
        output CS_n,
        output MOSI,
        input MISO
    );
    
    reg [3:0] r_wb_sel;
    reg       r_wb_we;
    reg       r_wb_cyc;
    reg       r_wb_stb;
    
    reg  [31:0] r_wb_rdt;
    wire [31:0] w_wb_rdt;
    wire        w_wb_ack;
    
    flash_controller u0(
        // Wishbone slave
        .i_wb_clk ( clk          ),
        .i_wb_rst ( !rst_n       ),
        .i_wb_adr ( 32'h00000000 ),
        .i_wb_dat ( 32'h00000000 ),
        .i_wb_sel ( r_wb_sel     ),
        .i_wb_we  ( r_wb_we      ),
        .i_wb_cyc ( r_wb_cyc     ),
        .i_wb_stb ( r_wb_stb     ),
        .o_wb_rty (              ),
        .o_wb_rdt ( w_wb_rdt     ),
        .o_wb_ack ( w_wb_ack     ),
        // SPI
        .SCK      ( SCK ),   
        .CS_n     ( CS_n ),
        .MOSI     ( MOSI ),
        .MISO     ( MISO )
    );
    
    parameter S_IDLE   = 0,
              S_WRITE  = 1,
              S_WAIT   = 2,
              S_UPDATE = 3;
              
    reg [1:0] state, next;
    
    always @(posedge clk)
        if (!rst_n) state <= S_IDLE;
        else state <= next;
        
    always @(*)
        case (state)
            S_IDLE:   next = enable? S_WRITE: S_IDLE; 
            S_WRITE:  next = S_WAIT;
            S_WAIT:   next = w_wb_ack? S_UPDATE: S_WAIT; 
            S_UPDATE: next = S_IDLE;
            default:  next = S_IDLE;
        endcase
    
    always @(*) begin
        r_wb_sel = {4{(state == S_WRITE) || (state == S_WAIT)}};
//        r_wb_we  = (state == S_WRITE) || (state == S_WAIT);
        r_wb_we  = 1'b0;
        r_wb_cyc = (state == S_WRITE) || (state == S_WAIT);
        r_wb_stb = (state == S_WRITE) || (state == S_WAIT);
        
    end
    
    always @(posedge clk)
        if (!rst_n) r_wb_rdt <= 32'd0;
        else if (state == S_UPDATE) r_wb_rdt <= w_wb_rdt;
        
    assign dout = r_wb_rdt[31:24] + r_wb_rdt[23:16] + r_wb_rdt[15:8] + r_wb_rdt[7:0];
    
endmodule
