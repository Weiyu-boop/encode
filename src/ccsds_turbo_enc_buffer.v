`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/10 17:26:15
// Design Name: 
// Module Name: ccsds_turbo_enc_buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 用于缓存输入的info序列
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ccsds_turbo_enc_buffer(
    input wire          clk,
    input wire          rstn,
    // buffer1
    input wire          i_ena,      // write
    input wire          i_write,
    input wire    [13:0] i_waddr,    //[clog2(2*K)-1:0]
    input wire          i_wdata,
    //
    input wire          i_read1,     // read
    input wire    [13:0] i_raddr1,
    //
    output wire         o_rsc1_idata,  // rsc1 编码输入
    
    // buffer2
    //input wire          i_ena,
    //input wire          i_write,
    //input wire    [3:0] i_waddr,
    //input wire          i_wdata,
    //
    input wire          i_read2,
    input wire    [13:0] i_raddr2,   // 交织地址
    //
    output wire         o_rsc2_idata  // rsc2 编码输入
    );
    
    
    // 用于输出RSC1编码数据
    /* 8 bits test
buffer_info_rsc1 buffer_info_rsc1_dpram16x1 (
  .clka(clk),    // input wire clka
  .ena(i_ena),      // input wire ena
  .wea(i_write),      // input wire [0 : 0] wea
  .addra(i_waddr),  // input wire [3 : 0] addra
  .dina(i_wdata),    // input wire [0 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(i_read1),      // input wire enb
  .addrb(i_raddr1),  // input wire [3 : 0] addrb
  .doutb(o_rsc1_idata)  // output wire [0 : 0] doutb
);
    */
dpram16384x1_rsc1_buf buffer_rsc1_info (
  .clka(clk),    // input wire clka
  .ena(i_ena),      // input wire ena
  .wea(i_write),      // input wire [0 : 0] wea
  .addra(i_waddr),  // input wire [13 : 0] addra
  .dina(i_wdata),    // input wire [0 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(i_read1),      // input wire enb
  .addrb(i_raddr1),  // input wire [13 : 0] addrb
  .doutb(o_rsc1_idata)  // output wire [0 : 0] doutb
);


    //用于输出RSC2编码数据
    /*
buffer_info_rsc2 buffer_info_rsc2_dpram16x1 (
  .clka(clk),    // input wire clka
  .ena(i_ena),      // input wire ena
  .wea(i_write),      // input wire [0 : 0] wea
  .addra(i_waddr),  // input wire [3 : 0] addra
  .dina(i_wdata),    // input wire [0 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(i_read2),      // input wire enb
  .addrb(i_raddr2),  // input wire [3 : 0] addrb
  .doutb(o_rsc2_idata)  // output wire [0 : 0] doutb
);*/
dpram16384x1_rsc2_buf buffer_rsc2_info (
  .clka(clk),    // input wire clka
  .ena(i_ena),      // input wire ena
  .wea(i_write),      // input wire [0 : 0] wea
  .addra(i_waddr),  // input wire [13 : 0] addra
  .dina(i_wdata),    // input wire [0 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(i_read2),      // input wire enb
  .addrb(i_raddr2),  // input wire [13 : 0] addrb
  .doutb(o_rsc2_idata)  // output wire [0 : 0] doutb
);
endmodule
