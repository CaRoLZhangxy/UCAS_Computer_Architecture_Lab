`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,

    //lab8
    output        ws_ex           ,
    output        eret_flush      ,
    output [31:0] c0_epc          ,
    output        flush           ,
    output        interrupt       ,

    //Lab14
    output        tlb_reflush     ,
    output        ws_mtc0         ,
    output        inst_tlbwi      ,
    output [31:0] c0_entryhi      ,
    output [31:0] c0_entrylo0     ,
    output [31:0] c0_entrylo1     ,
    output [31:0] c0_index        ,
    input         es_tlbp         ,
    input         tlbp_found      ,
    input [ 3: 0]          index           ,
    input  [18: 0]          r_vpn2          ,     
    input  [ 7: 0]          r_asid          ,     
    input                   r_g             ,     
    input  [19: 0]          r_pfn0          ,     
    input  [ 2: 0]          r_c0            ,     
    input                   r_d0            ,     
    input                   r_v0            ,     
    input  [19: 0]          r_pfn1          ,     
    input  [ 2: 0]          r_c1            ,     
    input                   r_d1            ,     
    input                   r_v1            ,

    //Lab15
    output                  tlb_refill
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire [ 3:0] ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

//lab8
wire inst_mtc0;
wire inst_mfc0;
wire mtc0_we;
wire ms_ex;
wire [ 7: 0] c0_addr;
wire [ 4: 0] ms_excode;
wire [ 4: 0] ws_excode;
wire wb_bd;
wire eret;
wire [5:0] ext_int_in;

wire [31: 0] c0_status          ;
wire [31: 0] c0_compare         ;
wire [31: 0] c0_count           ;
wire [31: 0] c0_badvaddr        ;
wire [31: 0] c0_cause           ;
wire [31: 0] c0_result          ;
wire [31: 0] badvaddr_value     ;
wire [ 7: 0] c0_status_im       ;
wire [ 7: 0] c0_cause_ip        ;
wire         c0_status_exl      ;
wire         count_eq_compare   ;

//Lab14

wire inst_tlbr;



assign {tlb_refill  ,  //125:125
        inst_tlbwi  ,  //124:124
        inst_tlbr   ,  //123:123
        badvaddr_value ,  //122:91
        wb_bd          ,  //90:90
        c0_addr        ,  //89:82
        ms_ex          ,  //81:81
        ms_excode      ,  //80:76
        eret           ,  //75:75
        inst_mtc0      ,  //74:74
        inst_mfc0      ,  //73:73
        ws_gr_we       ,  //72:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire [3 :0]  rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {ws_valid,  //41:41
                       rf_we   ,  //40:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (flush) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = (ws_valid & !ws_ex) ? ws_gr_we : 4'h0;
assign rf_waddr = ws_dest;
assign rf_wdata = inst_mfc0 ? c0_result : ws_final_result;


assign mtc0_we = ws_valid & inst_mtc0 & ! ws_ex;
assign eret_flush = ws_valid ? eret : 1'b0 ;
assign ext_int_in = 6'b0 ;
assign ws_ex = ws_valid ? ms_ex : 1'b0 ;
assign flush = ws_valid & (eret | ws_ex | tlb_reflush);//Lab14 modify
assign ws_excode = ws_valid ? ms_excode : 5'b0 ;

assign c0_status_im  = c0_status [15:8];
assign c0_cause_ip   = c0_cause  [15:8];
assign c0_status_exl = c0_status [1]   ;
assign c0_status_ie  = c0_status [0]   ;
assign interrupt = (count_eq_compare ||((c0_cause_ip & c0_status_im) != 8'b0) ) & c0_status_ie & ~c0_status_exl & ws_valid ;
//Lab14
assign tlb_reflush = ws_valid ? (inst_tlbr|inst_tlbwi):1'b0;
assign ws_mtc0     = mtc0_we & (c0_addr == `CR_ENTRYHI);



cp0 u_cp0(
    .clk(clk),
    .reset(reset),
    .c0_wdata(ws_final_result),
    .mtc0_we(mtc0_we),
    .c0_addr(c0_addr),
    .wb_ex(ws_ex),
    .wb_bd(wb_bd),
    .eret_flush(eret_flush),
    .ext_int_in(ext_int_in),
    .wb_excode(ws_excode),
    .wb_pc(ws_pc),
    .wb_badvaddr(badvaddr_value),
    .tlbp(es_tlbp)            ,
    .tlbp_found(tlbp_found)      ,
    .tlbr(inst_tlbr)            ,
    .index(index)          ,
    .r_vpn2(r_vpn2)        ,     
    .r_asid(r_asid)        ,     
    .r_g(r_g)              ,     
    .r_pfn0(r_pfn0)        ,     
    .r_c0(r_c0)            ,     
    .r_d0(r_d0)            ,     
    .r_v0(r_v0)            ,     
    .r_pfn1(r_pfn1)        ,     
    .r_c1(r_c1)            ,     
    .r_d1(r_d1)            ,     
    .r_v1(r_v1)            ,
    
    .c0_status(c0_status),
    .c0_cause(c0_cause),
    .c0_epc(c0_epc),
    .c0_compare(c0_compare),
    .c0_count(c0_count),
    .c0_badvaddr(c0_badvaddr),
    .count_eq_compare(count_eq_compare),
    .c0_entryhi(c0_entryhi)      ,
    .c0_entrylo0(c0_entrylo0)     ,
    .c0_entrylo1(c0_entrylo1)     ,
    .c0_index(c0_index)        
);

assign c0_result = (c0_addr == `CR_STATUS)   ? c0_status   :
                   (c0_addr == `CR_CAUSE)    ? c0_cause    :
                   (c0_addr == `CR_EPC)      ? c0_epc      :
                   (c0_addr == `CR_COMPARE)  ? c0_compare  : 
                   (c0_addr == `CR_COUNT)    ? c0_count    :
                   (c0_addr == `CR_BADVADDR) ? c0_badvaddr :
                   (c0_addr == `CR_ENTRYHI)  ? c0_entryhi  :
                   (c0_addr == `CR_ENTRYLO0) ? c0_entrylo0 :
                   (c0_addr == `CR_ENTRYLO1) ? c0_entrylo1 :
                   (c0_addr == `CR_INDEX)    ? c0_index    :
                   32'b0;


// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = rf_we;
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;

endmodule
