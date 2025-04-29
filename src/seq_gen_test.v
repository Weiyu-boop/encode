`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/22 11:18:19
// Design Name: 
// Module Name: seq_gen_test
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


module seq_gen_test#(
    parameter PATTERN = 0   //0:全5(101) 1:全A(1010)
)(
    input wire clk,
    input wire rstn,
    input wire ena,
    output wire data_out,
    output wire data_out_valid
    );
    
    localparam MAX_CNT = (PATTERN==0) ? 2 : 3;
    reg [1:0]cnt;
    // 计数
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            cnt <= 2'b0;
        else if(ena)
            cnt <= (cnt==MAX_CNT) ? 2'b0 : cnt + 1'b1;
        else 
            cnt <= 2'b0;
    end
    // 循环输出
    reg data_out_r;
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            data_out_r <= 1'b0;
        else if(ena)
            case({PATTERN,cnt})
                3'b0_00 : data_out_r <= 1'b1;   //全5模式
                3'b0_01 : data_out_r <= 1'b0;
                3'b0_10 : data_out_r <= 1'b1;
                
                3'b1_00 : data_out_r <= 1'b1;   //全A模式
                3'b1_01 : data_out_r <= 1'b0;
                3'b1_10 : data_out_r <= 1'b1;
                3'b1_11 : data_out_r <= 1'b0;
                
                default : data_out_r <= 1'b0;
            endcase
    end
    assign data_out = data_out_r;
    // 输出使能
    reg data_out_en;
    always  @(posedge clk or negedge rstn)begin
        if(!rstn)
            data_out_en <= 1'b0;
        else if(ena)
            data_out_en <= 1'b1;
        else
            data_out_en <= 1'b0;
    end
    assign data_out_valid = data_out_en;
    
endmodule
