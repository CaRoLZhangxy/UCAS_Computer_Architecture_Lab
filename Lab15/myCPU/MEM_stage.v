`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    output [31:0]                  ms_forward_data,
    //from data-sram
    //input  [31                 :0] data_sram_rdata,
    //data sram-like interface

    input [31:0]                   data_sram_rdata,
    input                          data_sram_data_ok,

    output                         ms_ex          ,
    output                         ms_eret           ,
    input                          flush          ,
    //Lab10
    output                         load_op        ,
    output                         out_ms_valid   ,
    //Lab14
    output                         ms_mtc0_valid        ,
    output                         ms_tlb_reflush         
);



reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire [ 3:0] ms_gr_we;
wire [ 3:0] ms_final_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
//Lab7
wire        inst_lw;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
wire  [ 1:0]addr_low;
wire  [ 3:0]lwl_wen;
wire  [ 3:0]lwr_wen;
wire  [31:0]lb_data;
wire  [31:0]lbu_data;
wire  [31:0]lh_data;
wire  [31:0]lhu_data;
wire  [31:0]lwl_data;
wire  [31:0]lwr_data;

wire        ms_mfc0 ;
wire        ms_bd   ;
wire  [7:0] c0_addr ;
wire  [4:0] ms_excode;
wire        es_ex   ;
wire  [4:0]es_excode;
wire [31:0]badvaddr_value;

wire ms_store;//lab10
wire eret;
assign ms_eret = ms_valid & eret;
//Lab14
wire inst_tlbr;
wire inst_tlbwi;
assign ms_mtc0_valid = ms_valid & ms_mtc0 & (c0_addr == `CR_ENTRYHI);
assign ms_tlb_reflush = ms_valid & (inst_tlbr | inst_tlbwi);
//Lab15
wire tlb_refill;

assign {tlb_refill,//134:134
        inst_tlbwi  ,  //133:133
        inst_tlbr   ,  //132:132
        ms_store,//131:131
        inst_lw,   //130:130
        badvaddr_value,//129:98
        ms_bd    ,//97:97
        c0_addr  ,//96:89
        es_ex    ,//88:88
        es_excode,//87:83
        eret   ,  //82:82
        ms_mtc0,  //81:81
        ms_mfc0,  //80:80
        inst_lb,  //79:79
        inst_lbu, //78:78
        inst_lh,  //77:77
        inst_lhu, //76:76
        inst_lwl, //75:75
        inst_lwr,  //74:74
        ms_res_from_mem,  //73:73
        ms_gr_we       ,  //72:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {tlb_refill  ,//125:125
                       inst_tlbwi  ,  //124:124
                       inst_tlbr   ,  //123:123
                       badvaddr_value       , //122:91
                       ms_bd                ,  //90:90
                       c0_addr              ,  //89:82
                       ms_ex                ,  //81:81
                       ms_excode            ,  //80:76
                       ms_eret                 ,  //75:75
                       ms_mtc0              ,  //74:74
                       ms_mfc0              ,  //73:73
                       ms_final_gr_we       ,  //72:69
                       ms_dest              ,  //68:64
                       ms_final_result      ,  //63:32
                       ms_pc                   //31:0
                      };

assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (flush) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

assign out_ms_valid = ms_valid; //lab10

assign addr_low       = ms_alu_result[1:0];
assign lbu_data = (addr_low==2'b00)?{24'h000000,data_sram_rdata[7:0]}:
				  (addr_low==2'b01)?{24'h000000,data_sram_rdata[15:8]}:
				  (addr_low==2'b10)?{24'h000000,data_sram_rdata[23:16]}:
				  (addr_low==2'b11)?{24'h000000,data_sram_rdata[31:24]}:0;
assign lb_data  = (addr_low==2'b00)?{{24{data_sram_rdata[7]}},data_sram_rdata[7:0]}:
				  (addr_low==2'b01)?{{24{data_sram_rdata[15]}},data_sram_rdata[15:8]}:
				  (addr_low==2'b10)?{{24{data_sram_rdata[23]}},data_sram_rdata[23:16]}:
				  (addr_low==2'b11)?{{24{data_sram_rdata[31]}},data_sram_rdata[31:24]}:0;
assign lhu_data = (addr_low==2'b10)?{16'h0000,data_sram_rdata[31:16]}:{16'h0000,data_sram_rdata[15:0]};
assign lh_data  = (addr_low==2'b10)?{{16{data_sram_rdata[31]}},data_sram_rdata[31:16]}:{{16{data_sram_rdata[15]}},data_sram_rdata[15:0]}; 
assign lwl_data = (addr_low==2'b00)?{data_sram_rdata[7:0],24'd0}:
				  (addr_low==2'b01)?{data_sram_rdata[15:0],16'd0}:
				  (addr_low==2'b10)?{data_sram_rdata[23:0],8'd0}:
				  data_sram_rdata;
assign lwr_data = (addr_low==2'b11)?{24'd0,data_sram_rdata[31:24]}:
				  (addr_low==2'b10)?{16'd0,data_sram_rdata[31:16]}:
				  (addr_low==2'b01)?{8'd0,data_sram_rdata[31:8]}:
				  data_sram_rdata;
assign lwl_wen  = (addr_low==2'b00)?4'b1000:
				  (addr_low==2'b01)?4'b1100:
				  (addr_low==2'b10)?4'b1110:
				  4'b1111;
assign lwr_wen  = (addr_low==2'b00)?4'b1111:
				  (addr_low==2'b01)?4'b0111:
				  (addr_low==2'b10)?4'b0011:
				  4'b0001;

assign ms_final_gr_we = inst_lwl ? lwl_wen : 
                        inst_lwr ? lwr_wen :
                        ms_gr_we;

assign mem_result = inst_lb  ? lb_data: 
                    inst_lbu ? lbu_data: 
                    inst_lh  ? lh_data:
                    inst_lhu ? lhu_data: 
                    inst_lwl ? lwl_data:
                    inst_lwr ? lwr_data:  
                    data_sram_rdata;

assign ms_forward_data = ms_final_result;


//lab8

assign ms_ex        = (ms_valid) ? es_ex : 1'b0     ;
assign ms_excode    = (ms_valid) ? es_excode : 5'b0 ;


//Lab10
assign       load_op = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr;
assign       ms_ready_go =((!ms_store & !load_op) || (data_sram_data_ok || ms_ex));
assign ms_final_result = ms_res_from_mem ?  mem_result
                                         : ms_alu_result;

endmodule
