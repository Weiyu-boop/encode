`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/10 17:31:47
// Design Name: 
// Module Name: ccsds_turbo_enc_ctrl
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


module ccsds_turbo_enc_ctrl#(
    parameter K = 8160
)(
    input wire clk,
    input wire rst_n,
    //input wire i_data_en,
    input wire i_frame_ram1_done,
    input wire i_frame_ram2_done,
    input wire fifo_overflow,   //给一个FIFO溢出标志
    //
    output wire rom_en,
    output wire fetch_en,
    output wire rsc_en,
    output wire o_term,
    //
    output wire st_enc1,    //编码RAM空间1
    output wire st_enc2,    //编码RAM空间2
    output wire enc1_start, //编码1起始标志
    output wire enc2_start, //编码2起始标志
    output wire enc1_done,  //编码1完成标志   即编码计数达到K-1
    output wire enc2_done,  //编码2完成标志
    //
    output wire reset,          //输出 复位
    output wire alert,          //输出 告警 warning
    output wire data_in_ctrl    //输出 数据写入控制信号
    );
    // 复位
    wire rstn;
    assign rstn = rst_n & reset;
    //state
    localparam IDLE = 3'b000;       // 空闲
    localparam ENC1 = 3'b001;       // 编码RAM空间1
    localparam RSC_TERM1 = 3'b010;  // RAM空间1RSC编码归零终止
    localparam ENC2 = 3'b011;       // 编码RAM空间2
    localparam RSC_TERM2 = 3'b100;  // RAM空间2RSC编码归零终止
    localparam WARNING = 3'b101;    // 若FIFO溢出，则进入告警状态，并且进行复位持续10拍
    
    reg [2:0] state;
    //reg [$clog2(K)-1:0] addr_cnt;   // 缓存地址计数
    reg [$clog2(K)-1:0] rsc_cnt;    // 编码计数
    
    reg [1:0] term_cnt;             // 终止计数
    
    
    //reg [6:0] reset_cnt = 0;            //复位计数: 当FIFO溢出后，系统进行复位，暂定持续100个clk
    //reg [9:0] reset_cnt = 0;
    reg [9:0] warn_cnt = 0;
    // main state machine
    // 注后续会多加一个FIFO溢出而导致的告警状态，之后进行系统复位     
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)
            state <= IDLE;
        else begin
            case(state)
                IDLE        :   begin
                                if(fifo_overflow)               state <= WARNING;
                                else if(i_frame_ram1_done)      state <=    ENC1;
                                else if(i_frame_ram2_done)      state <=    ENC2;
                                else                            state <=    IDLE;
                                end
                
                ENC1        :   begin
                                if(fifo_overflow)           state <= WARNING;
                                else if(rsc_cnt==K-1)       state <= RSC_TERM1;
                                else                        state <= ENC1;
                                end
                
                RSC_TERM1   :   begin
                                if(fifo_overflow)           state <= WARNING;
                                else if(term_cnt==2'd3)     state <= i_frame_ram2_done ? ENC2 : IDLE; 
                                else                        state <= RSC_TERM1; 
                                end

                ENC2        :   begin
                                if(fifo_overflow)           state <= WARNING;
                                else if(rsc_cnt==K-1)       state <= RSC_TERM2;
                                else                        state <= ENC2;
                                end
                
                RSC_TERM2   :   begin
                                if(fifo_overflow)           state <= WARNING;
                                else if(term_cnt==2'd3)     state <= i_frame_ram1_done ? ENC1 : IDLE;
                                else                        state <= RSC_TERM2;
                                end
                                
                WARNING     :   state <= (warn_cnt==10'd1000) ? IDLE : WARNING;
                
                default     :   state <= IDLE;
            endcase
        end
    end
    //-----------------------------Transitions-----------------------------//
    // transition 1:ENC状态 转换至 RSC_TERM状态 条件逻辑
    // ROM使能rom_en/ RAM读取使能fetch_en/ RSC编码使能rsc_en
    reg [$clog2(K):0] rom_cnt;
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            rom_cnt <= 'b0;
        else if((state==ENC1) || (state==ENC2))
            rom_cnt <= rom_cnt + 1'b1;
        else
            rom_cnt <= 'b0;
    end
    assign rom_en = ((state==ENC1)||(state==ENC2)) && (rom_cnt<=K-1); //output rom_en
    
    // fetch_en, rsc_en     延迟打拍
    reg rom_en_dly1,rom_en_dly2;
    always @(posedge clk or negedge rstn)begin
        if(!rstn) begin
            rom_en_dly1 <= 1'b0;
            rom_en_dly2 <= 1'b0;
        end  
        else begin
            rom_en_dly1 <= rom_en;
            rom_en_dly2 <= rom_en_dly1;
        end
    end
    assign fetch_en = rom_en_dly1;  // output fetch_en
    assign rsc_en = rom_en_dly2;    // output rsc_en
    
    // rsc_cnt 计数至K-1时，状态切换为编码终止
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            rsc_cnt <= 'b0;
        else if(rsc_en)
            rsc_cnt <= (rsc_cnt==K-1) ? 'b0 : rsc_cnt + 1'b1;
        else
            rsc_cnt <= 'b0;
    end
    
    // transition 2:归零终止RSC_TERM 状态切换条件
    // 归零计数
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            term_cnt <= 2'b0;
        else if((state==RSC_TERM1) || (state==RSC_TERM2))
            term_cnt <= (term_cnt==2'd3) ? 2'b0 : term_cnt + 1'b1;
        else
            term_cnt <= 2'b0; 
    end
    
   
    //---------------------------------------------------------------------//Transitions
    
    
    
    //-------------------------------WARNING-------------------------------//
    /*   一直复位会导致FIFO IP核无法重启恢复工作
    reg reset_r = 1'b1;
    always @(posedge clk)begin
        if(state==WARNING) begin
            reset_cnt <= reset_cnt + 1'b1;
            reset_r <= 1'b0;
        end
        else begin
            reset_cnt <= 10'b0;
            reset_r <= 1'b1;
        end
    end
    */
    reg reset_r = 1'b1;
    always @(posedge clk)begin  //warning报警持续1001个clk
        if(state==WARNING)
            warn_cnt <= warn_cnt + 1'b1;
        else
            warn_cnt <= 10'b0;
    end
    always @(posedge clk)begin  //复位持续10个clk
        if((state==WARNING)&&(warn_cnt < 10))
            reset_r = 1'b0;
        else
            reset_r = 1'b1;
    end
    
    // 数据写入控制信号 ：当进入WARNING状态时，不允许数据写入FIFO
    reg data_in_ctrl_r = 1'b1;
    always @(posedge clk)begin
        if(state==WARNING)
            data_in_ctrl_r <= 1'b0;
        else
            data_in_ctrl_r <= 1'b1;
    end
        
    //-------------------------------WARNING-------------------------------//
    
    
    //-------------------------------Outputs-------------------------------//
    // Part1
    reg state_enc1_dly;
    reg state_enc2_dly;
    always @(posedge clk)begin
        state_enc1_dly <= (state==ENC1);
        state_enc2_dly <= (state==ENC2);
    end
    assign enc1_start = (state==ENC1) && !state_enc1_dly;
    assign enc2_start = (state==ENC2) && !state_enc2_dly;
    
    assign enc1_done = (state==ENC1) && (rsc_cnt==K-1);
    assign enc2_done = (state==ENC2) && (rsc_cnt==K-1);
    // Part2
    // rom_en , fetch_en , rsc_en
    assign o_term = (state==RSC_TERM1) || (state==RSC_TERM2);
    assign st_enc1 = (state==ENC1);
    assign st_enc2 = (state==ENC2);
    
    assign reset = reset_r;
    assign alert = (state==WARNING);
    assign data_in_ctrl = data_in_ctrl_r;
    //-------------------------------Outputs-------------------------------//Outputs
endmodule
