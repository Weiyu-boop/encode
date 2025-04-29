`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/11 10:49:02
// Design Name: 
// Module Name: ccsds_turbo_enc_rsc
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


module ccsds_turbo_enc_rsc(
    input wire clk,
    input wire rstn,
    input wire i_data,
    input wire i_data_en,
    input wire i_terminate,
    //output wire o_data_s,        // 信息位
    //output wire [2:0] o_data_p,  // 校验位 {1a,2a,3a} 由高到低
    output wire o_data_en,
    output wire [3:0] o_data       //{s,1a,2a,3a} 由高到低
    );
    //parameter G0 = 5'b10011; //反馈支路
    parameter G1 = 5'b11011; //1a
    parameter G2 = 5'b10101; //2a
    parameter G3 = 5'b11111; //3a
    
    reg [3:0] D;    //4个寄存器
    wire feedback;
    assign feedback = i_terminate ? 1'b0 : i_data^D[1]^D[0];//ak
    /*ak_z = i_data ^ D[1] ^ D[0];
    ak_0 = D[1]^D[0]^D[1]^D[0];//0 此时 o_data_s = D[1]^D[0];*/
      
    //寄存器状态变化
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            D <= 4'b0;
        else if(i_data_en || i_terminate)
            D <= {feedback,D[3:1]};
        else
            D <= 4'b0;
    end
    reg o_data_s0;
    //信息位输出
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            o_data_s0 <= 1'b0;
        else if(i_data_en || i_terminate)
            o_data_s0 <= i_terminate ? D[1]^D[0] : i_data;
        else
            o_data_s0 <= 1'b0;
    end
    //assign o_data_s = o_data_s0;
    
    reg [2:0] o_data_p0;
    //校验位输出
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            o_data_p0 <= 3'b0;
        else if(i_data_en || i_terminate)begin
            o_data_p0[2] <= ^({feedback,D} & G1); //1a
            o_data_p0[1] <= ^({feedback,D} & G2); //2a
            o_data_p0[0] <= ^({feedback,D} & G3); //3a
        end   
        else
            o_data_p0 <= 3'b0;
    end
    //assign o_data_p = o_data_p0;
    
    assign o_data = {o_data_s0,o_data_p0};
    
    
    
    reg o_data_en0;
    //输出有效位
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            o_data_en0 <= 1'b0;
        else if(i_data_en || i_terminate)
            o_data_en0 <= 1'b1;
        else
            o_data_en0 <= 1'b0;
    end
    assign o_data_en = o_data_en0;
    
    
endmodule
