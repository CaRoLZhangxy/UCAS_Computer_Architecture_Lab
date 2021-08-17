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
    .c0_epc         (c0_epc         )
    //.flush          (flush          )
    //.ds_to_es_valid(ds_to_es_valid)
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
    .out_es_valid(es_valid)
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
    .out_ms_valid(ms_valid)
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
    .interrupt  (interrupt    )
);

endmodule
