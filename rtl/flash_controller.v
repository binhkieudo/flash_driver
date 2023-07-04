`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/29/2023 04:59:56 PM
// Design Name: 
// Module Name: flash_controller
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


module flash_controller(
        // Wishbone slave
        input        i_wb_clk,
        input        i_wb_rst,
        input [31:0] i_wb_adr,
        input [31:0] i_wb_dat,
        input [3:0]  i_wb_sel,
        input        i_wb_we,
        input        i_wb_cyc,
        input        i_wb_stb,
        output [31:0]o_wb_rty,
        output [31:0]o_wb_rdt,
        output       o_wb_ack,
        // SPI
        output SCK,
        output CS_n,
        output MOSI,
        input  MISO
    );
    
    parameter SPI_READ_STATUS     = 8'h05,
              SPI_WRITE_ENABLE    = 8'h06,
              SPI_PAGE_PROGRAM    = 8'h02,
              SPI_ERASE_SUBSECTOR = 8'h20,
              SPI_ERASE_SECTOR    = 8'hd8,
              SPI_ERASE_FULL      = 8'hc7,
              SPI_READ            = 8'h03;
              
    wire [7:0] TX_Byte;
    wire       TX_DV;
    wire       TX_Ready;
    
    wire [7:0] RX_Byte;
    wire       RX_DV;
    
    reg [31:0] r_wb_dat;
    reg [23:0] r_wb_adr;
    reg [3:0]  r_wb_sel;
    reg        r_write_mode;
    reg [2:0]  r_erase_mode;
    reg        is_busy;
    reg [7:0]  r_stall = 8'b0000_0001;
    
    reg [31:0] r_wb_rdt;
    reg        r_ack;
    reg        r_rty;
    
    reg [8:0]  byteCount;
    reg [4:0]  tryCount;
//    reg [8:0]  remain;
//    reg [2:0]  byte_write;
    
    SPI_Master spi_controller (
        .i_Rst_L    ( !i_wb_rst ) ,
        .i_Clk      ( i_wb_clk  ) ,
        .i_TX_Byte  ( TX_Byte   ) ,
        .i_TX_DV    ( TX_DV     ) ,
        .o_TX_Ready ( TX_Ready  ) ,
        .o_RX_DV    ( RX_DV     ) ,
        .o_RX_Byte  ( RX_Byte   ) ,
        .o_SPI_Clk  ( SCK       ) ,
        .i_SPI_MISO ( MISO      ) ,
        .o_SPI_MOSI ( MOSI      )
    );
    
    localparam S_IDLE        = 0,
               // Check status
               S_STATS_SEND  = 1,
               S_STATS_WAIT1 = 2,
               S_STATS_DUMMY = 3,
               S_STATS_WAIT2 = 4,
//               S_STATS_CHECK = 5,
               S_STATS_STALL = 5,
//               // Erase
//               S_ERAS_SEND   = 7,
//               S_ERAS_WAIT   = 8,
//               S_ERAS_STALL  = 9,
               // Write enable
               S_WREN_SEND   = 6,
               S_WREN_WAIT   = 7,
               S_WREN_STALL  = 8,
               // Send CMD
               S_CMD_SEND    = 9,
               S_CMD_WAIT    = 10,
               // Send Address
               S_SEND_ADDR2  = 11,
               S_WAIT_ADDR2  = 12,
               S_SEND_ADDR1  = 13,
               S_WAIT_ADDR1  = 14,
               S_SEND_ADDR0  = 15,
               S_WAIT_ADDR0  = 16,
               // Send Data
               S_DATA_LOAD   = 17,
               S_DATA3_SEND  = 18,
               S_DATA3_WAIT  = 19,
               S_DATA2_SEND  = 20,
               S_DATA2_WAIT  = 21,
               S_DATA1_SEND  = 22,
               S_DATA1_WAIT  = 23,
               S_DATA0_SEND  = 24,
               S_DATA0_WAIT  = 25,
               S_ACK         = 26,
//               S_NEXT_CHECK  = 31,
               S_RETRY       = 27,
               S_DONE        = 28;
   
   reg [4:0]state, next;
   
   always @(posedge i_wb_clk)
    if (i_wb_rst) state <= S_IDLE;
    else state <= next;    
   
   always @(*)
    case (state)
        S_IDLE:         next = (i_wb_cyc && i_wb_stb)? S_STATS_SEND: S_IDLE;
//        S_IDLE      :   next = S_CMD_SEND;
        // Check status
        S_STATS_SEND:   next = S_STATS_WAIT1;
        S_STATS_WAIT1:  next = TX_Ready? S_STATS_DUMMY: S_STATS_WAIT1;
        S_STATS_DUMMY:  next = S_STATS_WAIT2;
        S_STATS_WAIT2:  next = TX_Ready? S_STATS_STALL: S_STATS_WAIT2;
//        S_STATS_CHECK:  next = is_busy? S_STATS_SEND: S_STATS_STALL;
        S_STATS_STALL:  next = r_stall[7]? 
                               (is_busy? (tryCount[4]? S_RETRY: S_STATS_SEND): 
                               (r_write_mode? S_WREN_SEND: S_CMD_SEND)): S_STATS_STALL;
//        S_STATS_STALL:  next = r_stall[7]? S_IDLE: S_STATS_STALL;
        // Write enable
        S_WREN_SEND:    next = S_WREN_WAIT;
        S_WREN_WAIT:    next = TX_Ready? S_WREN_STALL: S_WREN_WAIT;
        S_WREN_STALL:   next = r_stall[7]? S_CMD_SEND: S_WREN_STALL;
        // Send cmd
        S_CMD_SEND:     next = S_CMD_WAIT;
        S_CMD_WAIT:     next = TX_Ready? (r_erase_mode[2]? S_IDLE: S_SEND_ADDR2): S_CMD_WAIT;
        // Send address
        S_SEND_ADDR2:   next = S_WAIT_ADDR2;
        S_WAIT_ADDR2:   next = TX_Ready? S_SEND_ADDR1: S_WAIT_ADDR2;
        S_SEND_ADDR1:   next = S_WAIT_ADDR1;
        S_WAIT_ADDR1:   next = TX_Ready? S_SEND_ADDR0: S_WAIT_ADDR1;
        S_SEND_ADDR0:   next = S_WAIT_ADDR0;
        S_WAIT_ADDR0:   next = TX_Ready? (|r_erase_mode[1:0]? S_DONE: S_DATA_LOAD): S_WAIT_ADDR0;
        // Send data
        S_DATA_LOAD :   next = i_wb_stb? S_DATA3_SEND: S_DATA_LOAD;
        S_DATA3_SEND:   next = S_DATA3_WAIT;
        S_DATA3_WAIT:   next = TX_Ready? S_DATA2_SEND: S_DATA3_WAIT;
        S_DATA2_SEND:   next = S_DATA2_WAIT;
        S_DATA2_WAIT:   next = TX_Ready? S_DATA1_SEND: S_DATA2_WAIT;
        S_DATA1_SEND:   next = S_DATA1_WAIT;
        S_DATA1_WAIT:   next = TX_Ready? S_DATA0_SEND: S_DATA1_WAIT;
        S_DATA0_SEND:   next = S_DATA0_WAIT;
        S_DATA0_WAIT:   next = TX_Ready? S_ACK: S_DATA0_WAIT;
        // Done
        S_ACK       :   next = (i_wb_cyc && byteCount[8])? (i_wb_stb? S_DATA_LOAD: S_DONE): S_DONE;
        S_RETRY     :   next = S_DONE;
//        S_NEXT_CHECK:   next = ;
        S_DONE      :   next = r_stall[7]? S_IDLE: S_DONE;
        default     :   next = S_IDLE;
    endcase 
    
    always @(posedge i_wb_clk) begin
        if (i_wb_rst) r_wb_dat <= 32'd0;
        else if ((state == S_DATA_LOAD) && i_wb_we && i_wb_stb) r_wb_dat <= i_wb_dat & {32{r_write_mode}};
        
        if (i_wb_rst) r_wb_adr <= 24'd0;
        else if ((state == S_IDLE) && i_wb_cyc) r_wb_adr <= i_wb_adr[23:0];
        
        if (i_wb_rst) r_wb_sel <= 4'd0;
        else if ((state == S_IDLE) && i_wb_cyc) r_wb_sel <= i_wb_sel; 
        
        if (i_wb_rst || (state == S_DONE)) r_write_mode <= 1'b0;
        else if ((state == S_IDLE) && i_wb_cyc) r_write_mode <= i_wb_we; 
        
        if (i_wb_rst || (state == S_DONE)) r_erase_mode <= 1'b0;
        else if ((state == S_IDLE) && i_wb_cyc) r_erase_mode <= {3{i_wb_we}} & i_wb_adr[31:29]; 
                
        if (i_wb_rst || (state == S_STATS_SEND)) is_busy <= 1'b0;
        else if ((state == S_STATS_WAIT2) && RX_DV) is_busy <= RX_Byte[0]; // busy bit
        
        if (i_wb_rst || (state == S_STATS_SEND)) r_stall <= 8'b0000_0001;
        else if ((state == S_STATS_STALL) || (state == S_DONE) || (state == S_WREN_STALL)) r_stall <= {r_stall[6:0], r_stall[7]};
        
        if (state == S_IDLE) byteCount <= 9'd0;
        else if ((state == S_DATA_LOAD) && i_wb_stb) byteCount <= byteCount + 9'd4; 
        
        if (state == S_IDLE) tryCount <= 5'd0;
        else if (state == S_STATS_SEND) tryCount <= tryCount + 1'b1;
    end
    
    always @(posedge i_wb_clk) begin
        if ((state == S_DATA3_WAIT) && RX_DV) r_wb_rdt[31:24] <= RX_Byte & {8{r_wb_sel[3]}};
        if ((state == S_DATA2_WAIT) && RX_DV) r_wb_rdt[23:16] <= RX_Byte & {8{r_wb_sel[2]}};
        if ((state == S_DATA1_WAIT) && RX_DV) r_wb_rdt[15:8]  <= RX_Byte & {8{r_wb_sel[1]}};
        if ((state == S_DATA0_WAIT) && RX_DV) r_wb_rdt[7:0]   <= RX_Byte & {8{r_wb_sel[0]}};
        
        if (i_wb_rst || (state == S_IDLE)) r_ack <= 1'b0;
        else r_ack <= (((state == S_DATA0_WAIT) || (state == S_WAIT_ADDR0)) && (next == S_ACK));
        
        if (i_wb_rst || (state == S_IDLE)) r_rty <= 1'b0;
        else r_rty <= state == S_RETRY;
                
    end
    
    assign TX_Byte = (state == S_STATS_SEND)? SPI_READ_STATUS:
                     (state == S_WREN_SEND )? SPI_WRITE_ENABLE:
                     (state == S_CMD_SEND)  ? ( r_erase_mode[2]? SPI_ERASE_FULL:
                                                r_erase_mode[1]? SPI_ERASE_SECTOR:
                                                r_erase_mode[0]? SPI_ERASE_SUBSECTOR:
                                                r_write_mode? SPI_PAGE_PROGRAM: SPI_READ ):
                     (state == S_SEND_ADDR2)? r_wb_adr[23:16]:
                     (state == S_SEND_ADDR1)? r_wb_adr[15:8]:
                     (state == S_SEND_ADDR0)? r_wb_adr[7:0]:
                     (state == S_DATA3_SEND)? r_wb_dat[31:24]:
                     (state == S_DATA2_SEND)? r_wb_dat[23:16]:
                     (state == S_DATA1_SEND)? r_wb_dat[15:8]:
                     (state == S_DATA0_SEND)? r_wb_dat[7:0]: 8'h00;
                     
    assign TX_DV = (state == S_STATS_SEND ) ||
                   (state == S_STATS_DUMMY) ||
                   (state == S_WREN_SEND  ) ||
                   (state == S_CMD_SEND   ) ||
                   (state == S_SEND_ADDR2 ) ||
                   (state == S_SEND_ADDR1 ) ||
                   (state == S_SEND_ADDR0 ) ||
                   ((state == S_DATA3_SEND) && i_wb_sel[3]) ||
                   ((state == S_DATA2_SEND) && i_wb_sel[2]) ||
                   ((state == S_DATA1_SEND) && i_wb_sel[1]) ||
                   ((state == S_DATA0_SEND) && i_wb_sel[0]);
    
    assign CS_n = (state == S_IDLE       ) ||
                  (state == S_STATS_STALL) ||
                  (state == S_WREN_STALL ) ||
                  (state == S_DONE       );
                   
    assign o_wb_rdt = r_wb_rdt;
    assign o_wb_ack = r_ack;
    assign o_wb_rty = r_rty;
    
endmodule
