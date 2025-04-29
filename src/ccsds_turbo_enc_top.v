`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/10 17:17:44
// Design Name: Wang JH
// Module Name: ccsds_turbo_enc_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: CCSDS 标准下的 turbo 码编码器顶层文件
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ccsds_turbo_enc_top#(
    parameter K     =   8160,      //信息位长度
    parameter rate  =   2       //码率，可选2(1/2) or 3(1/3) or 4(1/4) or 6(1/6)
)(
    input wire clk_in,         // FIFO读取时钟以及编码器主时钟
    //input wire clk_wr,      // FIFO写入时钟
    //input wire rst_n,
    //input wire i_data_wr,
    //input wire i_data_wr_en,
    //input wire rate_sel,    // 码率选择: 00=1/2 , 01=1/3 , 10=1/4 , 11=1/6
    //input wire enable,
    output wire [rate-1:0] o_data,
    output wire o_data_valid,
    output wire Alarm
    );
    //--------------------上板调试----------------------//
    wire clk;
    wire rst_n;
    wire enable;
    BUFG BUFG_inst (
      .O(clk), // 1-bit output: Clock output    40M
      .I(clk_in)  // 1-bit input: Clock input
   );
   wire clk_10M;
   wire clk_20M;
   wire locked;
  clk_wiz_0_test u0_clk_wiz
   (
    // Clock out ports
    .clk_out1(clk_10M),     // output clk_out1
    .clk_out2(clk_20M),     // output clk_out2
    // Status and control signals
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(clk));      // input clk_in1    
    
    
    // ila核观测
    ila_0_output u0_ila_output (
	.clk(clk), // input wire clk

	.probe0(o_data), // input wire [1:0]  probe0  
	.probe1(o_data_valid), // input wire [0:0]  probe1 
	.probe2(Alarm) // input wire [0:0]  probe2
);
    
    // vio
    vio_0 u0_vio_output (
  .clk(clk),                // input wire clk
  .probe_out0(rst_n),  // output wire [0 : 0] probe_out0
  .probe_out1(enable)  // output wire [0 : 0] probe_out1
);
    
    //-------------------上板调试----------------------//
      
    
    //------test-------//
    wire i_data_wr;
    wire i_data_wr_en;
    //-----------------//
    
    
  //------------------------------------------------------------------------------------------------------
  // variables declaration
  //------------------------------------------------------------------------------------------------------
    // FIFO
    wire fifo_overflow;
    wire i_data;
    wire i_data_en;
    
    // buffer
    wire [13:0] i_waddr;    //[$clog2(2*K)-1:0]
    wire [13:0] i_raddr1;
    wire o_rsc1_idata;
    
    wire [13:0] i_raddr2;
    wire o_rsc2_idata;
    
    wire busy;              //RAM空间忙标志，反馈给FIFO，作为其数据读出条件
    reg busy_ram1;          //RAM空间1忙标志
    reg busy_ram2;          //RAM空间2忙标志
    
    wire frame_ram1_done;   //RAM空间1帧写完标志
    wire frame_ram2_done;   //RAM空间2帧写完标志
    // ROM
    wire [12:0] addr_rom;
    wire [12:0] addr_inter;    // 交织地址
    //wire romena = rom_en;
    
    // enc_ctrl
    wire rom_en;            //ROM读取使能
    wire fetch_en;          //RAM读取使能
    wire rsc_en;            //RSC1/2工作使能
    wire o_term;            //RSC1/2归零终止标志
    //wire st_enc1;           //编RAM1空间
    wire st_enc2;           //编RAM2空间
    wire enc1_start;        //编码1起始标志
    wire enc2_start;        //编码2起始标志
    wire enc1_done;         //编码1完成标志
    wire enc2_done;         //编码2完成标志
    wire alert;             //系统告警
    wire flag_frame_in;     //帧传输标志
    wire reset;             //内部复位
    wire data_in_ctrl;      //FIFO输出控制
    
    wire rstn;
    assign rstn = rst_n & reset;    //rst_n为外界系统复位，reset为系统内部复位
    
    // enc_rsc
    wire [3:0] o_rsc1_odata;
    wire o_rsc1_data_en;
    wire [3:0] o_rsc2_odata;
    //wire o_rsc2_data_en;
  
  //---------test-----------//
  seq_gen_test#
    (.PATTERN(0) )//0:全5(101) 1:全A(1010)
    seq_gen_u1
    (
    .clk(clk),  //clk_wr
    .rstn(rstn),
    .ena(enable),
    .data_out(i_data_wr),
    .data_out_valid(i_data_wr_en)
    );
  //------------------------// test
    
    
  //------------------------------------------------------------------------------------------------------
  // Data Interface FIFO
  //------------------------------------------------------------------------------------------------------
    ccsds_turbo_enc_fifo#(.K(K))
    enc_fifo
    (
    .clk_wr(clk),   //clk_wr
    .clk_rd(clk),
    .rstn(rstn),
    .i_data_wr(i_data_wr),
    .i_data_wr_en(i_data_wr_en),
    //
    .i_ram_busy(busy),
    .i_data_in_ctrl(data_in_ctrl),
    //
    .o_data_rd(i_data),
    .o_data_valid(i_data_en),
    .overflow(fifo_overflow)
    );
    
    
  //------------------------------------------------------------------------------------------------------
  // BUFFER : input data buffer RAM for rsc1 and rsc2
  //------------------------------------------------------------------------------------------------------
    ccsds_turbo_enc_buffer enc_buffer(
    .clk(clk),
    .rstn(rstn),
    // buffer1
    .i_ena(i_data_en),      // write
    .i_write(i_data_en),
    .i_waddr(i_waddr),
    .i_wdata(i_data),
    //
    .i_read1(fetch_en),     // read
    .i_raddr1(i_raddr1),    // 顺序地址
    //
    .o_rsc1_idata(o_rsc1_idata),  // rsc1 编码输入
    
    // buffer2
    //
    .i_read2(fetch_en),
    .i_raddr2(i_raddr2),   // 交织地址
    //
    .o_rsc2_idata(o_rsc2_idata)  // rsc2 编码输入
    );
    
    //-------------------------写地址-------------------------//
    // Part1 : 写入地址计数
    reg addr_M;                 // 最高位，切换写入区域  
    reg [12:0] addr_buf_w;      // [$clog2(K)-1:0]
    wire [13:0] addr_buf_write; // 写入RAM的地址
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            addr_buf_w <= 13'b0;
        else if(i_data_en)
            addr_buf_w <= (addr_buf_w==K-1) ? 13'b0 : addr_buf_w + 1'b1;
        else
            addr_buf_w <= 13'b0;
    end
    
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            addr_M <= 1'b0;
        else if(addr_buf_w==K-1)
            addr_M <= ~addr_M;
    end
    
    assign addr_buf_write = {addr_M,addr_buf_w};
    assign i_waddr = addr_buf_write;
    
    // Part2 : RAM busy 逻辑 
    // RAM 1 busy : RAM空间1 busy 逻辑
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            busy_ram1 <= 1'b0;
        else if(i_data_en&&(addr_buf_w==K-1)&&(addr_M==1'b0))
            busy_ram1 <= 1'b1;
        else if(enc1_done)      
            busy_ram1 <= 1'b0;
    end
    //RAM 2 busy : RAM空间2 busy 逻辑
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            busy_ram2 <= 1'b0;
        else if(i_data_en&&(addr_buf_w==K-1)&&(addr_M==1'b1))
            busy_ram2 <= 1'b1;
        else if(enc2_done)      
            busy_ram2 <= 1'b0;
    end
    
    assign busy = busy_ram1 && busy_ram2;
    
    // Part3 : 写完一帧标志驱动编码功能
    reg frame_ram1_done_r;
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            frame_ram1_done_r <= 1'b0;
        else if((addr_M==1'b0)&&(addr_buf_w==K-1))
            frame_ram1_done_r <= 1'b1;
        else if(enc1_start)     //编完状态机设置该变量
            frame_ram1_done_r <= 1'b0;
    end
    
    reg frame_ram2_done_r;
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            frame_ram2_done_r <= 1'b0;
        else if((addr_M==1'b1)&&(addr_buf_w==K-1))
            frame_ram2_done_r <= 1'b1;
        else if(enc2_start)     //编完状态机设置该变量
            frame_ram2_done_r <= 1'b0;
    end
    
    assign frame_ram1_done = frame_ram1_done_r;
    assign frame_ram2_done = frame_ram2_done_r;
    
    //--------------------------------------------------------//
    
    //-------------------------读地址-------------------------//
    // 读地址  同写地址   区分交织地址与顺序地址  fetch_en  **************待修改
    reg [12:0] addr_buf_r;
    wire [13:0] addr_buf_r1;
    wire [13:0] addr_buf_r2;
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            addr_buf_r <= 13'b0;
        else if(fetch_en)
            addr_buf_r <= (addr_buf_r==K-1) ? 13'b0 : addr_buf_r + 1'b1;
        else
            addr_buf_r <= 13'b0;
    end
    assign addr_buf_r1 = {1'b0,addr_buf_r};
    assign addr_buf_r2 = {1'b1,addr_buf_r};
    // i_raddr1 根据状态选择 编1存2选r1 编2存1选r2
    //assign i_raddr1 = st_enc1 ? addr_buf_r1 : addr_buf_r2;
    assign i_raddr1 = st_enc2 ? addr_buf_r2 : addr_buf_r1;
    
    // 读：交织地址选择
    wire [13:0] addr_inter1;
    wire [13:0] addr_inter2;
    assign addr_inter1 = {1'b0,addr_inter};
    assign addr_inter2 = {1'b1,addr_inter};
    // i_raddr2 根据状态选择 编1存2选1 编2存1选2
    //assign i_raddr2 = st_enc1 ? addr_inter1 : addr_inter2;
    assign i_raddr2 = st_enc2 ? addr_inter2 : addr_inter1;
    
    
  //------------------------------------------------------------------------------------------------------
  // ROM : interleave addresses
  //------------------------------------------------------------------------------------------------------
  /* 8bits test
rom8x3_inter rom_interleave (
  .clka(clk),    // input wire clka
  .ena(rom_en),      // input wire ena
  .addra(addr_rom),  // input wire [2 : 0] addra
  .douta(addr_inter)  // output wire [2 : 0] douta
);
*/
rom8160x13_inter rom_interleave (
  .clka(clk),    // input wire clka
  .ena(rom_en),      // input wire ena
  .addra(addr_rom),  // input wire [12 : 0] addra
  .douta(addr_inter)  // output wire [12 : 0] douta
);
    reg [12:0] addr_rom0;
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            addr_rom0 <= 13'b0;
        else if(rom_en)
            addr_rom0 <= (addr_rom0==K-1) ? 13'b0 : addr_rom0 + 1'b1;
        else
            addr_rom0 <= 13'b0;
    end
    assign addr_rom = addr_rom0;
    
    
  //------------------------------------------------------------------------------------------------------
  // CTRL : main FSM output control signal sequence
  //------------------------------------------------------------------------------------------------------
    ccsds_turbo_enc_ctrl#(.K(K))
    enc_ctrl
    (
    .clk(clk),
    .rst_n(rst_n),
    .i_frame_ram1_done(frame_ram1_done),
    .i_frame_ram2_done(frame_ram2_done),
    .fifo_overflow(fifo_overflow),   //给一个FIFO溢出标志
    //
    .rom_en(rom_en),
    .fetch_en(fetch_en),
    .rsc_en(rsc_en),
    .o_term(o_term),
    //
    .st_enc1(),    //编RAM1空间
    .st_enc2(st_enc2),    //编RAM2空间
    .enc1_start(enc1_start),
    .enc2_start(enc2_start),
    .enc1_done(enc1_done),
    .enc2_done(enc2_done),
    //
    .reset(reset),                      //输出 复位
    .alert(alert),                      //输出 告警 warning
    .data_in_ctrl(data_in_ctrl)
    );
    assign Alarm = alert;
    
  //------------------------------------------------------------------------------------------------------
  // RSC ENCODE
  //------------------------------------------------------------------------------------------------------
    ccsds_turbo_enc_rsc enc_rsc1(
    .clk(clk),
    .rstn(rstn),
    .i_data(o_rsc1_idata),
    .i_data_en(rsc_en),
    .i_terminate(o_term),
    //output wire o_data_s,        // 信息位
    //output wire [2:0] o_data_p,  // 校验位 {1a,2a,3a} 由高到低
    .o_data_en(o_rsc1_data_en),
    .o_data(o_rsc1_odata)       //{s,1a,2a,3a} 由高到低
    );
    
    ccsds_turbo_enc_rsc enc_rsc2(
    .clk(clk),
    .rstn(rstn),
    .i_data(o_rsc2_idata),
    .i_data_en(rsc_en),
    .i_terminate(o_term),
    //output wire o_data_s,        // 信息位
    //output wire [2:0] o_data_p,  // 校验位 {1a,2a,3a} 由高到低
    .o_data_en(),
    .o_data(o_rsc2_odata)       //{s,1b,2b,3b} 由高到低
    );
    
    
  //------------------------------------------------------------------------------------------------------
  // 删余复用       Output
  //------------------------------------------------------------------------------------------------------
    reg [rate-1:0] o_data_r;
    reg punct_cnt;
    always @(*)begin
        case(rate)
            2 : o_data_r <= (punct_cnt==1) ? {o_rsc1_odata[3],o_rsc2_odata[2]} : o_rsc1_odata[3:2];   //0a,1a,0a,1b
            3 : o_data_r <= {o_rsc1_odata[3:2],o_rsc2_odata[2]};                      // 0a,1a,1b
            4 : o_data_r <= {o_rsc1_odata[3],o_rsc1_odata[1:0],o_rsc2_odata[2]};      //0a,2a,3a,1b
            6 : o_data_r <= {o_rsc1_odata[3:0],o_rsc2_odata[2],o_rsc2_odata[0]};        //0a,1a,2a,3a,1b,3b
            default : o_data_r <= 'b0;
        endcase
    
    end
    // 1/2码率删余
    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            punct_cnt <= 1'b0;
        else if(o_rsc1_data_en)
            punct_cnt <= ~punct_cnt;
        else
            punct_cnt <= 1'b0;
    end
    
    assign o_data = o_data_r;
    assign o_data_valid = o_rsc1_data_en;
    
    
  //------------------------------------------------------------------------------------------------------
  // 缓存输出       Output      后续按需加一个输出FIFO
  //------------------------------------------------------------------------------------------------------
    //后续的组帧逻辑   位宽可变的FIFO
    
endmodule
