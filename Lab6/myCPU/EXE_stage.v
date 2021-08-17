`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    output [31:0] es_forward_data,
    output es_load_op
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
// Lab 6 Update 
wire        es_dest_hi;
wire        es_dest_lo;
wire        es_res_from_hi;
wire        es_res_from_lo;
wire [15:0] es_alu_op     ;
wire        es_src2_is_zimm;
// Update end

wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;


assign {es_dest_lo,       //144:144 Lab6 Update
        es_dest_hi,       //143:143 ..
        es_res_from_hi,   //142:142 ..
        es_res_from_lo,   //141:141 ..
        es_src2_is_zimm,  //140:140 ..
        es_alu_op      ,  //139:124 Lab6 Update end here
        es_load_op     ,  //123:123
        es_src1_is_sa  ,  //122:122
        es_src1_is_pc  ,  //121:121
        es_src2_is_imm ,  //120:120
        es_src2_is_8   ,  //119:119
        es_gr_we       ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_alu_hi_result ;
wire [31:0] es_alu_lo_result ;

wire        es_res_from_mem;

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_final_result  ,  //63:32
                       es_pc             //31:0
                      };

assign es_ready_go    = es_alu_op[14] ? div_dout_tvalid:
                        es_alu_op[15] ? divu_dout_tvalid:
                        1'b1;//Update Lab6
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
//add zero extend
assign es_alu_src2 = es_src2_is_imm  ? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     es_src2_is_zimm ? {16'b0,es_imm[15:0]} :
                     es_src2_is_8    ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op[13:0]),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .mult_hi_result(es_alu_hi_result),
    .mult_lo_result(es_alu_lo_result)
    );


// cp0_hi cp0_lo
reg [31:0] cp0_hi;
reg [31:0] cp0_lo;

always @(posedge clk)
begin
    if (reset)
    begin
        cp0_hi <= 32'd0;
        cp0_lo <= 32'd0;
    end
    else if (es_alu_op[12]||es_alu_op[13])
    begin
        cp0_hi <= es_alu_hi_result;
        cp0_lo <= es_alu_lo_result;
    end
    else if (div_dout_tvalid && es_alu_op[14])
    begin
        cp0_hi <= div_result[31:0];
        cp0_lo <= div_result[63:32];
    end
    else if (divu_dout_tvalid && es_alu_op[15])
    begin
        cp0_hi <= divu_result[31:0];
        cp0_lo <= divu_result[63:32];
    end
    else if (es_dest_hi)
    begin
        cp0_hi <= es_rs_value;
    end
    else if (es_dest_lo)
    begin
        cp0_lo <= es_rs_value;
    end
end

//add es_final_result
wire [31:0] es_final_result ;
assign es_final_result = es_res_from_lo ? cp0_lo : 
                         es_res_from_hi ? cp0_hi :
                         es_alu_result;

//dividers
wire [63:0] div_result;
wire [63:0] divu_result;

reg div_src_valid;
reg divu_src_valid;

wire div_divisor_tready;
wire divu_divisor_tready;
wire div_dividend_tready;
wire divu_dividend_tready;
wire div_dout_tvalid;
wire divu_dout_tvalid;

always @(posedge clk)
begin
    if(reset)
    begin
        div_src_valid  <= 1'b0;
    end
    else if (div_src_valid && div_divisor_tready & div_dividend_tready)
    begin
        div_src_valid  <= 1'b0;
    end
    else if (es_allowin & ds_to_es_valid )
    begin
        div_src_valid  <= ds_to_es_bus[138];
    end
end

always @(posedge clk)
begin
    if(reset)
    begin
        divu_src_valid  <= 1'b0;
    end
    else if (divu_src_valid && divu_divisor_tready & divu_dividend_tready)
    begin
        divu_src_valid  <= 1'b0;
    end
    else if (es_allowin & ds_to_es_valid)
    begin
        divu_src_valid  <= ds_to_es_bus[139];
    end
end


mydiv u_mydiv(
      .aclk (clk),
      .s_axis_divisor_tvalid (div_src_valid),
      .s_axis_divisor_tready  (div_divisor_tready),
      .s_axis_divisor_tdata  (es_rt_value),
      .s_axis_dividend_tvalid (div_src_valid),
      .s_axis_dividend_tready (div_dividend_tready),
      .s_axis_dividend_tdata (es_rs_value),
      .m_axis_dout_tvalid (div_dout_tvalid),
      .m_axis_dout_tdata (div_result)    
    );
    
mydiv_u u_mydivu(
      .aclk (clk),
      .s_axis_divisor_tvalid (divu_src_valid),
      .s_axis_divisor_tready  (divu_divisor_tready),
      .s_axis_divisor_tdata  (es_rt_value),
      .s_axis_dividend_tvalid (divu_src_valid),
      .s_axis_dividend_tready (divu_dividend_tready),
      .s_axis_dividend_tdata (es_rs_value),
      .m_axis_dout_tvalid (divu_dout_tvalid),
      .m_axis_dout_tdata (divu_result)    
    );

assign es_forward_data = es_final_result;
assign data_sram_en    = 1'b1;
assign data_sram_wen   = es_mem_we&&es_valid ? 4'hf : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rt_value;

endmodule
