`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/16 11:58:55
// Design Name: 
// Module Name: ccsds_turbo_enc_sim
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


module ccsds_turbo_enc_sim();

    parameter K = 8160;
    parameter rate = 2;
    reg clk_wr;
    reg clk_rd;
    reg rst_n;
    //reg i_data;
    //reg i_data_en;
    reg enable;
    wire [rate-1:0] o_data;
    wire o_data_valid;
    //wire done;
    wire Alarm;
    reg [13:0] wr_cnt;
    
    ccsds_turbo_enc_top#(.K(K), .rate(rate)) 
    enc_test(
    .clk(clk_rd),
    .clk_wr(clk_wr),
    .rst_n(rst_n),
    //.i_data_wr(i_data),
    //.i_data_wr_en(i_data_en),
    .enable(enable),
    .o_data(o_data),
    .o_data_valid(o_data_valid),
    .Alarm(Alarm)
    );
    
    
    initial begin
    clk_wr = 0;
    clk_rd = 0;
    end
    always #6 clk_wr = ~clk_wr;
    always #10 clk_rd = ~clk_rd;
    
    initial begin
        rst_n = 0;
        //i_data = 0;
        //i_data_en = 0;
        enable = 0;
        #200;
        
        
        rst_n = 1;
        #800;
        
        enable = 1;
        /*repeat(200000) begin
            i_data = $random % 2;
            #20;
        end
        i_data_en = 0;*/
        
        #5000000;
    end

    integer save_file;
    initial begin
        save_file = $fopen("E:/code/vivado_files/CCSDS_Turbo/CCSDS_Turbo_Enc2_pingpong/output_record/output_mazi2.txt","w");
        if(save_file==0)begin
            $display("can not open the file!");
            $stop;
        end
        
    end
    
    always @(posedge clk_rd)begin
        if(o_data_valid && (wr_cnt<8164))begin
            $fdisplay(save_file,"%b",o_data);
        end
        else if(wr_cnt==8164)
            $fclose(save_file);
    end
    always @(posedge clk_rd)begin
        if(!rst_n)
            wr_cnt <= 14'b0;
        else if(o_data_valid)begin
            wr_cnt <= wr_cnt + 1'b1;
        end
    end
    
    
endmodule
