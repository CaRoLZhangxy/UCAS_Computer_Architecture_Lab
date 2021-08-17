`include "mycpu.h"
module sram_cpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    /*output        inst_sram_en,
    output [ 3:0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_en,
    output [ 3:0] data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,*/

    //************lab10*****************
    //inst sram like interface
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,

    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    //data sram like interface
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata,

    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [31:0] es_forward_data;
wire [31:0] ms_forward_data;
wire es_load_op;
//Lab8
wire ds_branch_op;
wire ws_ex       ;
wire eret_flush  ;
wire [31:0] c0_epc;
wire flush;  
wire ms_ex;
wire ms_eret;   
//Lab9
wire interrupt;
//lab10
wire mem_load_op;
wire ms_valid;
wire es_valid;

//lab14
wire [18:0] s0_vpn2;
wire s0_odd_page;     
//wire [7:0] s0_asid;     
wire s0_found;     
wire [3:0] s0_index;     
wire [19:0] s0_pfn;     
wire [2:0] s0_c;    
wire s0_d;  
wire s0_v; 
wire [18:0] s1_vpn2;     
wire s1_odd_page;  
//wire [7:0] s1_asid;   
wire s1_found;    
wire [3:0] s1_index;     
wire [19:0] s1_pfn;     
wire [2:0] s1_c;    
wire s1_d;  
wire s1_v; 
//wire we;      
wire [3:0] w_index;     
wire [18:0] w_vpn2;     
wire [7:0] w_asid;     
wire  w_g;     
wire [19:0] w_pfn0;    
wire [2:0] w_c0;    
wire w_d0; 
wire w_v0;     
wire [19:0] w_pfn1;     
wire [2:0] w_c1;     
wire w_d1;     
wire w_v1;    
wire [3:0] r_index;     
wire [18:0] r_vpn2;     
wire [7:0] r_asid;     
wire r_g;     
wire [19:0] r_pfn0;     
wire [2:0] r_c0;     
wire r_d0;     
wire r_v0;     
wire [19:0] r_pfn1;     
wire [2:0] r_c1;     
wire r_d1;    
wire r_v1;
wire tlb_reflush;
wire tlbwi;
wire es_tlbp;
wire ms_tlb_reflush;
wire ms_mtc0;
wire ws_mtc0;
wire [31:0] c0_entryhi      ;
wire [31:0] c0_entrylo0     ;
wire [31:0] c0_entrylo1     ;
wire [31:0] c0_index        ;

// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface

    // inst-sram like interface
    .inst_sram_req(inst_sram_req),
    .inst_sram_wr(inst_sram_wr),
    .inst_sram_size(inst_sram_size),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata),
    .ds_branch_op   (ds_branch_op   ),
    .ws_ex          (ws_ex          ),
    .eret_flush     (eret_flush     ),
    .c0_epc         (c0_epc         ),
    .tlb_reflush    (tlb_reflush)    ,
    .s0_vpn2(s0_vpn2),
    .s0_odd_page(s0_odd_page),     
    //.s0_asid(s0_asid),     
    .s0_found(s0_found),     
    .s0_index(s0_index),     
    .s0_pfn(s0_pfn),     
    .s0_c(s0_c),     
    .s0_d(s0_d),     
    .s0_v(s0_v)
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    .ms_to_ws_valid (ms_to_ws_valid ),
    .es_to_ms_valid (es_to_ms_valid ),
    .es_forward_data (es_forward_data),
    .ms_forward_data (ms_forward_data),
    .es_load_op (es_load_op)          ,
    .ds_branch_op   (ds_branch_op   ) ,
    .flush          (flush           ),
    .interrupt      (interrupt       ),
    .mem_load_op    (mem_load_op     ),
    .data_read_ok   (data_sram_data_ok),
    .es_valid (es_valid),
    .ms_valid (ms_valid)
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    /*.data_sram_en   (data_sram_en   ),
    .data_sram_wen  (data_sram_wen  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),*/
    // data sram like interface
    .data_sram_req  (data_sram_req),
    .data_sram_wr   (data_sram_wr),
    .data_sram_size (data_sram_size),
    .data_sram_addr (data_sram_addr),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_data_ok(data_sram_data_ok),
    .es_forward_data (es_forward_data),
    .es_load_op (es_load_op)         ,
    .flush (flush),
    .ms_ex (ms_ex   ),
    .ms_eret (ms_eret   ),
    .out_es_valid(es_valid),
    .es_tlbp(es_tlbp),
    .ms_mtc0(ms_mtc0),
    .ws_mtc0(ws_mtc0),
    .ms_tlb_reflush(ms_tlb_reflush),
    .tlb_reflush(tlb_reflush),
    .s1_vpn2(s1_vpn2),
    .s1_odd_page(s1_odd_page),
    //.s1_asid(s1_asid),
    .s1_found(s1_found),
    .s1_index(s1_index),
    .s1_pfn(s1_pfn),
    .s1_c(s1_c),
    .s1_d (s1_d),
    .s1_v(s1_v),
    .c0_entryhi(c0_entryhi)            
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),
    .ms_forward_data (ms_forward_data),
    .ms_eret(ms_eret),
    .ms_ex (ms_ex   ),
    .flush(flush),
    .load_op      (mem_load_op       ),
    .out_ms_valid(ms_valid)          ,
    .ms_tlb_reflush(ms_tlb_reflush),
    .ms_mtc0_valid(ms_mtc0)
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),

    .ws_ex      (ws_ex        ),
    .eret_flush (eret_flush   ),
    .c0_epc     (c0_epc       ),
    .flush      (flush        ),
    .interrupt  (interrupt    ),
    .tlb_reflush(tlb_reflush)  ,
    .ws_mtc0(ws_mtc0),
    .c0_entryhi(c0_entryhi)      ,
    .c0_entrylo0(c0_entrylo0)     ,
    .c0_entrylo1(c0_entrylo1)     ,
    .c0_index(c0_index)    ,
    .index(s1_index[3:0])  ,
    .es_tlbp(es_tlbp)      ,
    .tlbp_found(s1_found)  ,
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
    .inst_tlbwi(tlbwi)
);
tlb tlb(
    .clk(clk), 
    .s0_vpn2(s0_vpn2),
    .s0_odd_page(s0_odd_page),     
    .s0_asid(c0_entryhi[7:0]),     
    .s0_found(s0_found),     
    .s0_index(s0_index),     
    .s0_pfn(s0_pfn),     
    .s0_c(s0_c),     
    .s0_d(s0_d),     
    .s0_v(s0_v), 
    // search port 1     
    .s1_vpn2(s1_vpn2),     
    .s1_odd_page(s1_odd_page),     
    .s1_asid(c0_entryhi[7:0]),     
    .s1_found(s1_found),     
    .s1_index(s1_index),     
    .s1_pfn(s1_pfn),     
    .s1_c(s1_c),     
    .s1_d(s1_d),     
    .s1_v(s1_v), 
    // write port     
    .we(tlbwi),      
    .w_index(c0_index[3:0]),     
    .w_vpn2(c0_entryhi[31:13]),     
    .w_asid(c0_entryhi[7:0]),     
    .w_g(c0_entrylo0[0] & c0_entrylo1[0]),     
    .w_pfn0(c0_entrylo0[25:6]),     
    .w_c0(c0_entrylo0[5:3]),     
    .w_d0(c0_entrylo0[2]), 
    .w_v0(c0_entrylo0[1]),     
    .w_pfn1(c0_entrylo1[25:6]),     
    .w_c1(c0_entrylo1[5:3]),     
    .w_d1(c0_entrylo1[2]),     
    .w_v1(c0_entrylo1[1]), 
     // read port     
    .r_index(c0_index[3:0]),     
    .r_vpn2(r_vpn2),     
    .r_asid(r_asid),     
    .r_g(r_g),     
    .r_pfn0(r_pfn0),     
    .r_c0(r_c0),     
    .r_d0(r_d0),     
    .r_v0(r_v0),     
    .r_pfn1(r_pfn1),     
    .r_c1(r_c1),     
    .r_d1(r_d1),     
    .r_v1(r_v1) 
);

endmodule
