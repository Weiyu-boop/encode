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
// Description: turbo���������ݽӿ��߼�
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ccsds_turbo_enc_fifo#(
    parameter K = 8160             //��Ϣλ����
)(
    input wire clk_wr,
    input wire clk_rd,
    input wire rstn,
    input wire i_data_wr,
    input wire i_data_wr_en,
    //
    input wire i_ram_busy,      // RAM1��2�ռ��Ƿ�ռ�ã�1��ʾȫ��ռ��
    input wire i_data_in_ctrl,
    //
    output wire o_data_rd,
    output wire o_data_valid,
    output wire overflow
    );
    
    wire rd_en;         //��ʹ��
    wire rd_en_pulse;   //��ʹ�ܳ�ʼ����
    
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
    
    //����������
    //    1.֡��ɱ�־����д��һ֡���ݺ󣬼�wr_cnt=K-1������һ������frame_wdone��ͬ������ʱ����
    //    2.֡��������ʱ����frame_cnt��д��֡���м�������frame_wdoneͬ��������ʱ��+1����rd_en��������ʱ��-1��
    //    3.֡Ԥ�������־��frame_ready = frame_cnt>=1;��fifo�д洢��֡��������1֡ʱ��׼������
    //    4.fifo��ȡʹ�ܣ�rd_en������ͬʱ����frame_ready������flag_frame_in�������������߳���K��ʱ�Ӻ�����
    
    //---------------------֡��ɱ�־---------------------//
    // ֡��ɱ�־    дʱ����    д��һ֡����
    wire frame_wdone;
    reg [$clog2(K)-1:0] wr_data_cnt;    //д�����ݼ���
    always @(posedge clk_wr or negedge rstn)begin
        if(!rstn)
            wr_data_cnt <= 'b0;
        else if(i_data_en_wr)
            wr_data_cnt <= (wr_data_cnt==K-1) ? 'b0 : wr_data_cnt + 1'b1;   
    end
    assign frame_wdone = (wr_data_cnt==K-1);
    //--------------test-----------------------------------------------
    //����ʱ�����֡���źų�������clk_wr���߶��clk_wr������д�����ʸ��ڶ�ȡ�����ǣ���ȡʱ���ܹ��ȵ����źţ��Ҹ��߼���Ӱ��߶�ȡ�����߼�
    wire frame_wdone_s;
    reg frame_wdone_dly;
    always @(posedge clk_wr)begin
        frame_wdone_dly <= frame_wdone;
    end
    assign frame_wdone_s = frame_wdone || frame_wdone_dly;
    //--------------test------------------------------------------------
    //��ʱ����ͬ��    д-->��
    wire frame_d;   //�����źų���һ��clk
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
    
    //-----------------------֡����-----------------------//
    // ��ʱ����
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
    
    //---------------------֡Ԥ����־---------------------//
    wire frame_ready;
    assign frame_ready = (frame_cnt>=1);
    //----------------------------------------------------//
    
    //---------------------��ȡʹ���߼�-------------------//
    // ��ʱ����
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
    
    // ���ʹ��
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
