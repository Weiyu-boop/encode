`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/16 10:16:06
// Design Name: 
// Module Name: ccsds_turbo_enc_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: turbo编码器数据接口逻辑
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ccsds_turbo_enc_fifo#(
    parameter K = 8160             //信息位长度
)(
    input wire clk_wr,
    input wire clk_rd,
    input wire rstn,
    input wire i_data_wr,
    input wire i_data_wr_en,
    //
    input wire i_ram_busy,      // RAM1、2空间是否被占用，1表示全部占用
    input wire i_data_in_ctrl,
    //
    output wire o_data_rd,
    output wire o_data_valid,
    output wire overflow
    );
    
    wire rd_en;         //读使能
    wire rd_en_pulse;   //读使能初始脉冲
    
    wire full;
    //wire almost_full;
    
    wire empty;
    //wire almost_empty;
    wire underflow;
    
    wire [13:0] rd_data_count;
    wire [13:0] wr_data_count;
    
    wire i_data_en_wr;
    assign i_data_en_wr = i_data_wr_en & i_data_in_ctrl;
 /*     test   
  fifo15x1 data2enc_FIFO (
  .rst(!rstn),                      // input wire rst
  .wr_clk(clk_wr),                // input wire wr_clk
  .rd_clk(clk_rd),                // input wire rd_clk
  .din(i_data_wr),                      // input wire [0 : 0] din
  .wr_en(i_data_wr_en),                  // input wire wr_en
  .rd_en(rd_en),                  // input wire rd_en
  .dout(o_data_rd),                    // output wire [0 : 0] dout
  .full(full),                    // output wire full
  .almost_full(almost_full),      // output wire almost_full
  .wr_ack(),                // output wire wr_ack
  .overflow(overflow),            // output wire overflow
  .empty(empty),                  // output wire empty
  .almost_empty(almost_empty),    // output wire almost_empty
  .valid(o_data_valid),                  // output wire valid
  .underflow(underflow),          // output wire underflow
  .rd_data_count(rd_data_count),  // output wire [3 : 0] rd_data_count
  .wr_data_count(wr_data_count),  // output wire [3 : 0] wr_data_count
  .wr_rst_busy(),      // output wire wr_rst_busy
  .rd_rst_busy()      // output wire rd_rst_busy
);
*/
fifo16384x1_async data2enc_FIFO (
  .rst(!rstn),                      // input wire rst
  .wr_clk(clk_wr),                // input wire wr_clk
  .rd_clk(clk_rd),                // input wire rd_clk
  .din(i_data_wr),                      // input wire [0 : 0] din
  .wr_en(i_data_en_wr),                  // input wire wr_en
  .rd_en(rd_en),                  // input wire rd_en
  .dout(o_data_rd),                    // output wire [0 : 0] dout
  .full(full),                    // output wire full
  .wr_ack(),                // output wire wr_ack
  .overflow(overflow),            // output wire overflow
  .empty(empty),                  // output wire empty
  .valid(),                  // output wire valid
  .underflow(underflow),          // output wire underflow
  .rd_data_count(rd_data_count),  // output wire [13 : 0] rd_data_count
  .wr_data_count(wr_data_count),  // output wire [13 : 0] wr_data_count
  .wr_rst_busy(),      // output wire wr_rst_busy
  .rd_rst_busy()      // output wire rd_rst_busy
);
    
    //大致描述：
    //    1.帧完成标志：当写完一帧数据后，即wr_cnt=K-1，给出一个脉冲frame_wdone，同步到读时钟域
    //    2.帧计数：读时钟域frame_cnt对写入帧进行计数，当frame_wdone同步脉冲来时，+1；当rd_en拉高脉冲时，-1；
    //    3.帧预备传输标志：frame_ready = frame_cnt>=1;当fifo中存储的帧数不少于1帧时，准备传输
    //    4.fifo读取使能：rd_en拉高须同时满足frame_ready与输入flag_frame_in条件，并且拉高持续K个时钟后拉低
    
    //---------------------帧完成标志---------------------//
    // 帧完成标志    写时钟域    写完一帧数据
    wire frame_wdone;
    reg [$clog2(K)-1:0] wr_data_cnt;    //写入数据计数
    always @(posedge clk_wr or negedge rstn)begin
        if(!rstn)
            wr_data_cnt <= 'b0;
        else if(i_data_en_wr)
            wr_data_cnt <= (wr_data_cnt==K-1) ? 'b0 : wr_data_cnt + 1'b1;   
    end
    assign frame_wdone = (wr_data_cnt==K-1);
    //--------------test-----------------------------------------------
    //将读时钟域的帧满信号持续两个clk_wr或者多个clk_wr，便于写入速率高于读取速率是，读取时钟能够踩到该信号，且该逻辑不影响高读取速率逻辑
    wire frame_wdone_s;
    reg frame_wdone_dly;
    always @(posedge clk_wr)begin
        frame_wdone_dly <= frame_wdone;
    end
    assign frame_wdone_s = frame_wdone || frame_wdone_dly;
    //--------------test------------------------------------------------
    //跨时钟域同步    写-->读
    wire frame_d;   //脉冲信号持续一个clk
    reg [1:0] frame_wdone_sync;
    always @(posedge clk_rd or negedge rstn)begin
        if(!rstn)
            frame_wdone_sync <= 2'b00;
        else 
            //frame_wdone_sync <= {frame_wdone_sync[0],frame_wdone};
            frame_wdone_sync <= {frame_wdone_sync[0],frame_wdone_s};
    end
    reg frame_wdone_sync1_dly;
    always @(posedge clk_rd or negedge rstn)begin
        if(!rstn)
            frame_wdone_sync1_dly <= 1'b0;
        else 
            frame_wdone_sync1_dly <= frame_wdone_sync[1];
    end
    assign frame_d = frame_wdone_sync[1] && !frame_wdone_sync1_dly;
    //----------------------------------------------------//
    
    //-----------------------帧计数-----------------------//
    // 读时钟域
    reg [1:0] frame_cnt;
    always @(posedge clk_rd or negedge rstn)begin
        if(!rstn)
            frame_cnt <= 2'b00;
        else if(frame_d)
            frame_cnt <= frame_cnt + 1'b1;
        else if(rd_en_pulse)
            frame_cnt <= frame_cnt - 1'b1;
    end
    //----------------------------------------------------//
    
    //---------------------帧预备标志---------------------//
    wire frame_ready;
    assign frame_ready = (frame_cnt>=1);
    //----------------------------------------------------//
    
    //---------------------读取使能逻辑-------------------//
    // 读时钟域
    reg rd_en_r;
    reg [$clog2(K)-1:0] rd_data_cnt;
    always @(posedge clk_rd or negedge rstn)begin
        if(!rstn)
            rd_en_r <= 1'b0;
        else if(rd_data_cnt==K-1)
            rd_en_r <= 1'b0;
        else if(frame_ready && !i_ram_busy)
            rd_en_r <= 1'b1;
    end
    assign rd_en = rd_en_r;
    
    always @(posedge clk_rd or negedge rstn)begin
        if(!rstn)
            rd_data_cnt <= 'b0;
        else if(rd_en_r)
            rd_data_cnt <= (rd_data_cnt==K-1) ? 'b0 : rd_data_cnt + 1'b1;
        else 
            rd_data_cnt <= 'b0;
    end
    
    // rd_en_pulse
    reg rd_en_dly;
    always @(posedge clk_rd)begin
        rd_en_dly <= rd_en_r;
    end
    assign rd_en_pulse = rd_en_r && !rd_en_dly;
    //----------------------------------------------------//
    
    // 输出使能
    /*
    reg o_data_valid_r;
    always @(posedge clk_rd or negedge rstn)begin
        if(!rstn)
            o_data_valid_r <= 1'b0;
        else if(rd_en)
            o_data_valid_r <= 1'b1;
        else 
            o_data_valid_r <= 1'b0;
    end*/
    assign o_data_valid = rd_en_dly;
    
endmodule
