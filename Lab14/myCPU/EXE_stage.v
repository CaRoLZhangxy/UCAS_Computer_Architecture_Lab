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
    /*output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,*/
    // data sram like interface
    output         data_sram_req    ,
    output         data_sram_wr     ,
    output [2:0]   data_sram_size   ,
    output [31:0]  data_sram_addr   ,
    output [3:0]   data_sram_wstrb  ,
    output [31:0]  data_sram_wdata  ,
    
    input        data_sram_addr_ok  ,
    input        data_sram_data_ok  ,

    output [31:0] es_forward_data,
    output es_load_op            ,
    input  flush                 ,
    input  ms_ex                 ,
    input  ms_eret               ,
    output out_es_valid          ,
    output es_tlbp               ,
    input  ms_mtc0               ,
    input  ws_mtc0               ,
    input  ms_tlb_reflush        ,
    input  tlb_reflush           ,

    output [18:0] s1_vpn2         ,
    output        s1_odd_page     ,
    //output [ 7:0] s1_asid         ,
    input         s1_found        ,
    input  [ 3:0] s1_index        ,
    input  [19:0] s1_pfn          ,
    input  [ 3:0] s1_c            ,
    input         s1_d            ,
    input         s1_v            ,
    input  [31:0] c0_entryhi
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
//Lab7
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sb;
wire        inst_sh;
wire        inst_swl;
wire        inst_swr;
wire        inst_sw ;
wire        [1:0]addr_low ;
wire        [31:0]st_data ;
wire        [31:0]swl_data;
wire        [31:0]swr_data;


wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire [ 3:0] es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
//Lab8
wire        es_mfc0       ;
wire        es_mtc0       ;
wire        eret          ;
wire        es_bd         ;
wire [ 7:0] c0_addr       ;
wire        es_ex         ;
wire [ 4:0] es_excode     ;
wire        ds_ex         ;
wire [ 4:0] ds_excode     ;
wire        es_we         ; //inst (store and write c0 registers) can run
wire        overflow      ;
wire        inst_overflow ;
wire        exception_overflow ;
wire [31:0] PC_badvaddr   ;
wire [31:0] badvaddr_value;
wire        es_adel       ;
wire        es_ades       ;
wire        inst_lw       ;
wire [ 4:0] es_excode_temp;
//Lab14
wire        inst_tlbr;
wire        inst_tlbwi;
wire        inst_tlbp;
wire        es_tlbp;
assign      es_tlbp = es_valid & inst_tlbp;

//Lab10
wire        es_store;
assign      es_store = inst_sw | inst_sb | inst_sh | inst_swl | inst_swr;

assign  exception_overflow = inst_overflow & overflow;
assign  es_adel = (inst_lw & (addr_low != 2'b00)) |
                  (inst_lh & addr_low[0]) |
                  (inst_lhu & addr_low[0]);
assign  es_ades = (inst_sw & (addr_low != 2'b00)) |
                  (inst_sh & addr_low[0]);
assign  es_excode_temp = exception_overflow   ? 5'h0c :
                         es_adel              ? 5'h04 :
                         es_ades              ? 5'h05 : 5'b0 ;
assign  es_we =  es_valid ? (~flush & ~ms_ex & ~ms_eret & ~es_ex & ~ms_tlb_reflush & ~tlb_reflush):1'b0 ;//Lab14 Update
assign  es_ex =  es_valid ? (ds_ex | exception_overflow | es_ades | es_adel) : 1'b0;
assign  es_excode = es_valid ? (ds_ex ? ds_excode : es_excode_temp):5'b0 ;


assign {inst_tlbp   ,  //213:213
        inst_tlbwi  ,  //212:212
        inst_tlbr   ,  //211:211
        inst_lw     ,  //210:210
        PC_badvaddr,//209:178
        inst_overflow, //177:177
        es_bd       ,  //176:176
        ds_excode   ,  //175:171
        ds_ex       ,  //170:170
        c0_addr     ,  //169:162
        eret        ,  //161:161
        es_mtc0     ,  //160:160
        es_mfc0     ,  //159:159
        inst_sw     ,  //158:158
        inst_lb     ,  //157:157
        inst_lbu    ,  //156:156
        inst_lh     ,  //155:155
        inst_lhu    ,  //154:154
        inst_lwl    ,  //153:153
        inst_lwr    ,  //152:152
        inst_sb     ,  //151:151
        inst_sh     ,  //150:150
        inst_swl    ,  //149:149
        inst_swr    ,  //148:148
        es_dest_lo,       //147:147 Lab6 Update
        es_dest_hi,       //146:146 ..
        es_res_from_hi,   //145:145 ..
        es_res_from_lo,   //144:144 ..
        es_src2_is_zimm,  //143:143 ..
        es_alu_op      ,  //142:127 Lab6 Update end here
        es_load_op     ,  //126:126
        es_src1_is_sa  ,  //125:125
        es_src1_is_pc  ,  //124:124
        es_src2_is_imm ,  //123:123
        es_src2_is_8   ,  //122:122
        es_gr_we       ,  //121:118
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
//add es_final_result
wire [31:0] es_final_result ;

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {
                       inst_tlbwi  ,  //133:133
                       inst_tlbr   ,  //132:132
                       es_store,//131:131
                       inst_lw,//130:130
                       badvaddr_value,//129:98
                       es_bd    ,//97:97
                       c0_addr  ,//96:89
                       es_ex    ,//88:88
                       es_excode,//87:83
                       eret   ,  //82:82
                       es_mtc0,  //81:81
                       es_mfc0,  //80:80
                       inst_lb,  //79:79
                       inst_lbu, //78:78
                       inst_lh,  //77:77
                       inst_lhu, //76:76
                       inst_lwl, //75:75
                       inst_lwr,  //74:74
                       es_res_from_mem,  //73:73
                       es_gr_we       ,  //72:69
                       es_dest        ,  //68:64
                       es_final_result  ,  //63:32
                       es_pc             //31:0
                      };


                        
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (flush) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end
assign out_es_valid = es_valid;//lab10
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
    .mult_lo_result(es_alu_lo_result),
    .overflow      (overflow)
    );





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
    else if (es_allowin & ds_to_es_valid )
    begin
        div_src_valid  <= ds_to_es_bus[141];
    end
    else if (div_src_valid && div_divisor_tready & div_dividend_tready)
    begin
        div_src_valid  <= 1'b0;
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
        divu_src_valid  <= ds_to_es_bus[142];
    end
end
assign es_ready_go    = flush ? 1'b1 :
                        (inst_tlbp & (ms_mtc0 | ws_mtc0)) ? 1'b0: 
                        ((es_load_op | es_store) & (~data_sram_addr_ok | ~data_sram_req) & ~es_ex) ? 1'b0:
                        (es_alu_op[14] ? div_dout_tvalid:
                        es_alu_op[15] ? divu_dout_tvalid:
                        1'b1);//Update Lab6

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
    else if ((es_alu_op[12]||es_alu_op[13]) && es_we)
    begin
        cp0_hi <= es_alu_hi_result;
        cp0_lo <= es_alu_lo_result;
    end
    else if (div_dout_tvalid && es_alu_op[14] && es_we)
    begin
        cp0_hi <= div_result[31:0];
        cp0_lo <= div_result[63:32];
    end
    else if (divu_dout_tvalid && es_alu_op[15] && es_we)
    begin
        cp0_hi <= divu_result[31:0];
        cp0_lo <= divu_result[63:32];
    end
    else if (es_dest_hi && es_we)
    begin
        cp0_hi <= es_rs_value;
    end
    else if (es_dest_lo && es_we)
    begin
        cp0_lo <= es_rs_value;
    end
end
assign es_final_result = es_res_from_lo ? cp0_lo : 
                         es_res_from_hi ? cp0_hi :
                         es_mtc0        ? es_rt_value:
                         es_alu_result;
assign  badvaddr_value = (ds_ex && ds_excode == 5'h04) ? PC_badvaddr : es_alu_result;
//*********************data_sram*********************
reg request_control;
assign addr_low = es_alu_result[1:0];
assign swl_data = {32{(addr_low==2'b00)}}&{24'h000000,es_rt_value[31:24]}|
                  {32{(addr_low==2'b01)}}&{16'h0000,es_rt_value[31:16]}|
                  {32{(addr_low==2'b10)}}&{8'h00,es_rt_value[31:8]}|
				  {32{(addr_low==2'b11)}}&es_rt_value;
assign swr_data = {32{(addr_low==2'b00)}}&es_rt_value|
                  {32{(addr_low==2'b01)}}&{es_rt_value[23:0],8'h00}|
				  {32{(addr_low==2'b10)}}&{es_rt_value[15:0],16'h00}|
				  {32{(addr_low==2'b11)}}&{es_rt_value[7:0],24'h000000};

assign st_data  = inst_sb ? {4{es_rt_value[ 7:0]}} : 
                  inst_sh ? {2{es_rt_value[15:0]}} :
                  inst_swl?swl_data :
                  inst_swr?swr_data : es_rt_value ;

assign data_sram_wstrb   = es_mem_we&&es_we    ? ({4{inst_sb&&(addr_low==2'b00)}}&4'b0001|
						                        {4{inst_sb&&(addr_low==2'b01)}}&4'b0010|
                                                {4{inst_sb&&(addr_low==2'b10)}}&4'b0100|
                                                {4{inst_sb&&(addr_low==2'b11)}}&4'b1000|
                                                {4{inst_sh&&(addr_low==2'b10)}}&4'b1100|
                                                {4{inst_sh&&(addr_low==2'b00)}}&4'b0011|
                                                {4{inst_sw}}&4'b1111|
                                                {4{inst_swl&&(addr_low==2'b00)}}&4'b0001|
                                                {4{inst_swl&&(addr_low==2'b01)}}&4'b0011|
                                                {4{inst_swl&&(addr_low==2'b10)}}&4'b0111|
                                                {4{inst_swl&&(addr_low==2'b11)}}&4'b1111|
                                                {4{inst_swr&&(addr_low==2'b00)}}&4'b1111|
                                                {4{inst_swr&&(addr_low==2'b01)}}&4'b1110|
                                                {4{inst_swr&&(addr_low==2'b10)}}&4'b1100|
                                                {4{inst_swr&&(addr_low==2'b11)}}&4'b1000):4'h0;
assign data_sram_addr  =(inst_swl|inst_lwl) ? {es_alu_result[31:2],2'b00} : es_alu_result;
assign data_sram_wdata = st_data;

wire req_valid;
assign req_valid = es_valid ? (~flush ):1'b0;
assign data_sram_req  = (es_store | es_load_op) & ms_allowin & !request_control & es_we; 
always @(posedge clk)
begin
    if(reset)
    begin
        request_control <= 1'b0 ;
    end
    else if (request_control & data_sram_data_ok)
    begin
        request_control <= 1'b0 ;
    end
    else if (data_sram_req & data_sram_addr_ok)
    begin
        request_control <= 1'b1 ;
    end
    
end
assign data_sram_size = (inst_sw || inst_lw || 
                        ((inst_lwl || inst_swl) && (addr_low == 2'b10 || addr_low == 2'b11)) || 
                        ((inst_lwr || inst_swr) && (addr_low == 2'b00 || addr_low == 2'bb01))) ? 2'b10:
                        (inst_lh||inst_sh||inst_lhu||((inst_lwl || inst_swl) && addr_low == 2'b01) ||
						((inst_lwr || inst_swr) && addr_low == 2'b10)) ? 2'b01 : 2'b00;

assign data_sram_wr = es_store ? 1'b1 : 1'b0;



//Lab 14
assign s1_vpn2     = (es_tlbp)? c0_entryhi[31:13] : es_alu_result[31:13];
assign s1_odd_page = (es_tlbp)? c0_entryhi[12]  : es_alu_result[12];
//assign s1_asid     = (es_tlbp)? c0_entryhi[7:0] : 8'b0;

//wire [31:0] phy_addr;               
//assign phy_addr = (s1_found && s1_v)? {s1_pfn, es_alu_result[11:0]} : 32'b0;


endmodule
