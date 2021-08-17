`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus ,

    //
    input [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus ,
    input ms_to_ws_valid ,
    input es_to_ms_valid ,
    input [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus , 
    input [31:0] es_forward_data ,
    input [31:0] ms_forward_data ,
    input es_load_op                            ,
    
    //Lab8
    output ds_branch_op                         ,
    input  flush                                ,
    input  interrupt             
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire        ds_bd;
wire        fs_ex;
wire [ 4:0] fs_excode;
wire [31:0] badvaddr_value;
assign {badvaddr_value,//102:71
        fs_excode, //70:66
        fs_ex  ,   //65:65
        ds_bd  ,   //64:64
        ds_inst,   //63:32
        ds_pc      //31:0  
            } = fs_to_ds_bus_r;

wire [ 3:0] rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
wire ws_valid;
assign {ws_valid,  //41:41
        rf_we   ,  //40:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire [15:0] alu_op;
wire        dest_hi;
wire        dest_lo;
wire        res_from_hi;
wire        res_from_lo;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_simm;
wire        src2_is_zimm;
wire        src2_is_8;
wire        gr_we;
wire [3:0]  ds_gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;
wire [ 7:0] c0_addr;
wire [ 4:0] ds_excode;
wire [ 4:0] ds_excode_temp;
wire        ds_ex;
wire [ 2:0] c0_sel;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;

wire        inst_slti;
wire        inst_sltiu;
wire        inst_add;
wire        inst_addi;
wire        inst_sub;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sllv;
wire        inst_srlv;
wire        inst_srav;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mthi;
wire        inst_mflo;
wire        inst_mtlo;

wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j;
wire        inst_bltzal;
wire        inst_bgezal;
wire        inst_jalr;
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

wire        inst_syscall;
wire        inst_eret   ;
wire        inst_mtc0   ;
wire        inst_mfc0   ;
wire        inst_break  ;

wire        dst_is_r31;  
wire        dst_is_rt;  
wire        inst_overflow; 
wire        inst_valid;
wire        reserved_inst;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;

assign br_bus       = {br_taken,br_target};

assign ds_to_es_bus = {inst_lw     ,  //210:210   
                       badvaddr_value,//209:178
                       inst_overflow, //177:177
                       ds_bd       ,  //176:176
                       ds_excode   ,  //175:171
                       ds_ex       ,  //170:170
                       c0_addr     ,  //169:162
                       inst_eret   ,  //161:161
                       inst_mtc0   ,  //160:160
                       inst_mfc0   ,  //159:159
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
                       dest_lo     ,  //147:147
                       dest_hi     ,  //146:146
                       res_from_hi ,  //145:145
                       res_from_lo ,  //144:144
                       src2_is_zimm,  //143:143
                       alu_op      ,  //142:127
                       load_op     ,  //126:126
                       src1_is_sa  ,  //125:125
                       src1_is_pc  ,  //124:124
                       src2_is_simm,  //123:123
                       src2_is_8   ,  //122:122
                       ds_gr_we    ,  //121:118
                       mem_we      ,  //117:117
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };


assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (flush) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

assign c0_sel = ds_inst[2:0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
//Lab6 Update
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00] ;
assign inst_addi   = op_d[6'h08] ;
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00] ;
assign inst_slti   = op_d[6'h0a] ;
assign inst_sltiu  = op_d[6'h0b] ;
assign inst_div    = op_d[6'h00] & rd_d[5'h00]&sa_d[5'h00] & func_d[6'h1a];
assign inst_divu   = op_d[6'h00] & rd_d[5'h00]&sa_d[5'h00] & func_d[6'h1b];
assign inst_mult   = op_d[6'h00] & rd_d[5'h00]&sa_d[5'h00] & func_d[6'h18];
assign inst_multu  = op_d[6'h00] & rd_d[5'h00]&sa_d[5'h00] & func_d[6'h19];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_sllv   = op_d[6'h00] & sa_d[5'h00] & func_d[6'h04];
assign inst_srav   = op_d[6'h00] & sa_d[5'h00] & func_d[6'h07];
assign inst_srlv   = op_d[6'h00] & sa_d[5'h00] & func_d[6'h06];
assign inst_mfhi   = op_d[6'h00] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00] & func_d[6'h10];
assign inst_mflo   = op_d[6'h00] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00] & func_d[6'h12];
assign inst_mthi   = op_d[6'h00] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00] & func_d[6'h11];
assign inst_mtlo   = op_d[6'h00] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00] & func_d[6'h13];
//Lab7 Update
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01] ;
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00] ;
assign inst_blez   = op_d[6'h06] & rt_d[5'h00] ;
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00] ;
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11] ;
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10] ;
assign inst_j      = op_d[6'h02];
assign inst_jalr   = op_d[6'h00] & rt_d[5'h00] & sa_d[5'h00] & func_d[6'h09];
assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];
//Lab8 Update
assign inst_eret   = op_d[6'h10] & rs_d[5'h10] & rt_d[5'h00] & rt_d[5'h00] & sa_d[5'h00] & func_d[6'h18];
assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00] & sa_d[5'h00] & (ds_inst[5:3] == 3'b0);
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04] & sa_d[5'h00] & (ds_inst[5:3] == 3'b0);
assign inst_syscall= op_d[6'h00] & func_d[6'h0c];
assign inst_break   = op_d[6'h00] & func_d[6'h0d];

assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal | inst_add | inst_addi | inst_bltzal | inst_bgezal | inst_jalr |
                    inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_sb | inst_sh | inst_swl | inst_swr;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor ;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_sll | inst_sllv;
assign alu_op[ 9] = inst_srl | inst_srlv;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_mult;
assign alu_op[13] = inst_multu;
assign alu_op[14] = inst_div;
assign alu_op[15] = inst_divu;

assign load_op = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr ;
assign res_from_hi  = inst_mfhi;
assign res_from_lo  = inst_mflo;
assign dest_lo      = inst_mtlo;
assign dest_hi      = inst_mthi;
assign src1_is_sa   = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal | inst_bltzal | inst_bgezal | inst_jalr;
assign src2_is_simm = inst_addiu | inst_lui | inst_lw | inst_sw | inst_addi | inst_slti | inst_sltiu | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_sb | inst_sh | inst_swl | inst_swr ;
assign src2_is_zimm = inst_ori | inst_xori |inst_andi;
assign src2_is_8    = inst_jal | inst_bltzal | inst_bgezal | inst_jalr;
assign dst_is_r31   = inst_jal | inst_bgezal | inst_bltzal;
assign dst_is_rt    = inst_addiu | inst_lui | inst_lw | inst_addi | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_mfc0;
assign gr_we        = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr & ~inst_mthi & ~inst_mtlo & ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz & ~inst_j & ~inst_lwl & ~inst_lwr & ~inst_sb & ~inst_sh & ~inst_swl & ~inst_swr & ~inst_mtc0 ;
assign ds_gr_we        = {4{gr_we}};
assign mem_we       = inst_sw | inst_sb | inst_sh | inst_swl | inst_swr;
assign inst_overflow = inst_add | inst_addi | inst_sub;


assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
/* ***********************Update on Lab4************************* */
// delete on Lab5
/*
assign rs_value = rf_rdata1;
assign rt_value = rf_rdata2;
*/
//update on lab7
wire crash_on_es_valid;
wire crash_on_ms_valid;
wire crash_on_ws_valid;

assign crash_on_es_valid = (es_to_ms_bus[72] || es_to_ms_bus[71] || es_to_ms_bus[70] || es_to_ms_bus[69]) && es_to_ms_valid;
assign crash_on_ms_valid = (ms_to_ws_bus[72] || ms_to_ws_bus[71] || ms_to_ws_bus[70] || ms_to_ws_bus[69]) && ms_to_ws_valid;
assign crash_on_ws_valid = (rf_we[3] || rf_we[2] || rf_we[1] || rf_we[0]) && ws_valid;


wire crash_raddr1;
wire crash_raddr2;

assign crash_raddr1 =   (rf_raddr1 == 5'b0 ) ? 1'b0 :
                        ((rf_raddr1 == es_to_ms_bus[68:64]) && crash_on_es_valid && (es_load_op || es_to_ms_bus[80])) ? 1'b1 :
                        ((rf_raddr1 == ms_to_ws_bus[68:64]) && crash_on_ms_valid && ms_to_ws_bus[73]) ? 1'b1 :
                        //((rf_raddr1 == rf_waddr) && crash_on_ws_valid ) ?  1'b1  : 
                        1'b0;

assign crash_raddr2 =   (rf_raddr2 == 5'b0 ) ? 1'b0 :
                        ((rf_raddr2 == es_to_ms_bus[68:64]) && crash_on_es_valid && (es_load_op || es_to_ms_bus[80])) ? 1'b1 :
                        ((rf_raddr2 == ms_to_ws_bus[68:64]) && crash_on_ms_valid && ms_to_ws_bus[73]) ? 1'b1 :
                        //((rf_raddr2 == rf_waddr) && crash_on_ws_valid) ?  1'b1 : 
                        1'b0;
    
wire crash;
assign crash  = (inst_addu|inst_add|inst_subu|inst_sltu|inst_slt|inst_and|inst_or|inst_xor|inst_nor
                |inst_bne|inst_beq|inst_sw|inst_sb|inst_sh|inst_swl|inst_swr|inst_sllv|inst_srlv|inst_srav) ? 
                (crash_raddr1 | crash_raddr2) :
                (inst_addiu|inst_jr|inst_lw|inst_addi| inst_slti | inst_sltiu | inst_ori | inst_xori | inst_andi | inst_mtlo | inst_mthi 
                | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_bgez | inst_bgtz | inst_blez | inst_bltz | 
                inst_bgezal | inst_bltzal) ? crash_raddr1 : 
                (src1_is_sa | inst_mtc0) ? crash_raddr2 :
                1'b0;
//assign ds_ready_go = !crash;//delete on Lab5
/* ************************************************************** */
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );
/************************************Update on Lab7*********************************************/

assign rs_value[ 7: 0] =    (rf_raddr1 == 5'b0 ) ? 8'h00 :
                            ((rf_raddr1 == es_to_ms_bus[68:64]) && es_to_ms_bus[69] && crash_on_es_valid) ? es_forward_data [ 7: 0] :
                            ((rf_raddr1 == ms_to_ws_bus[68:64]) && ms_to_ws_bus[69] && crash_on_ms_valid) ? ms_forward_data [ 7: 0] :
                            ((rf_raddr1 == rf_waddr) && rf_we[0] && crash_on_ws_valid) ?  rf_wdata[ 7: 0]  : 
                            rf_rdata1[ 7: 0];
assign rt_value[ 7: 0] =    (rf_raddr2 == 5'b0 ) ? 8'h00 :
                            ((rf_raddr2 == es_to_ms_bus[68:64]) && es_to_ms_bus[69] && crash_on_es_valid) ? es_forward_data [ 7: 0] :
                            ((rf_raddr2 == ms_to_ws_bus[68:64]) && ms_to_ws_bus[69] && crash_on_ms_valid) ? ms_forward_data [ 7: 0]:
                            ((rf_raddr2 == rf_waddr) && rf_we[0] && crash_on_ws_valid) ?  rf_wdata[ 7: 0]  : 
                            rf_rdata2[ 7: 0];
assign rs_value[15: 8] =    (rf_raddr1 == 5'b0 ) ? 8'h00 :
                            ((rf_raddr1 == es_to_ms_bus[68:64]) && es_to_ms_bus[70] && crash_on_es_valid) ? es_forward_data [15: 8] :
                            ((rf_raddr1 == ms_to_ws_bus[68:64]) && ms_to_ws_bus[70] && crash_on_ms_valid) ? ms_forward_data [15: 8] :
                            ((rf_raddr1 == rf_waddr) && rf_we[1] && crash_on_ws_valid) ?  rf_wdata[15: 8]  : 
                            rf_rdata1[15: 8];
assign rt_value[15: 8] =    (rf_raddr2 == 5'b0 ) ? 8'h00 :
                            ((rf_raddr2 == es_to_ms_bus[68:64]) && es_to_ms_bus[70] && crash_on_es_valid) ? es_forward_data [15: 8] :
                            ((rf_raddr2 == ms_to_ws_bus[68:64]) && ms_to_ws_bus[70] && crash_on_ms_valid) ? ms_forward_data [15: 8]:
                            ((rf_raddr2 == rf_waddr) && rf_we[1] && crash_on_ws_valid) ?  rf_wdata[15: 8]  : 
                            rf_rdata2[15: 8];
assign rs_value[23:16] =    (rf_raddr1 == 5'b0 ) ? 8'h00 :
                            ((rf_raddr1 == es_to_ms_bus[68:64]) && es_to_ms_bus[71] && crash_on_es_valid) ? es_forward_data [23:16] :
                            ((rf_raddr1 == ms_to_ws_bus[68:64]) && ms_to_ws_bus[71] && crash_on_ms_valid) ? ms_forward_data [23:16] :
                            ((rf_raddr1 == rf_waddr) && rf_we[2] && crash_on_ws_valid) ?  rf_wdata[23:16]  : 
                            rf_rdata1[23:16];
assign rt_value[23:16] =    (rf_raddr2 == 5'b0 ) ? 8'h00 :
                            ((rf_raddr2 == es_to_ms_bus[68:64]) && es_to_ms_bus[71] && crash_on_es_valid) ? es_forward_data [23:16] :
                            ((rf_raddr2 == ms_to_ws_bus[68:64]) && ms_to_ws_bus[71] && crash_on_ms_valid) ? ms_forward_data [23:16]:
                            ((rf_raddr2 == rf_waddr) && rf_we[2] && crash_on_ws_valid) ?  rf_wdata[23:16]  : 
                            rf_rdata2[23:16];
assign rs_value[31:24] =    (rf_raddr1 == 5'b0 ) ? 8'h00 :
                            ((rf_raddr1 == es_to_ms_bus[68:64]) && es_to_ms_bus[72] && crash_on_es_valid) ? es_forward_data [31:24] :
                            ((rf_raddr1 == ms_to_ws_bus[68:64]) && ms_to_ws_bus[72] && crash_on_ms_valid) ? ms_forward_data [31:24] :
                            ((rf_raddr1 == rf_waddr) && rf_we[3] && crash_on_ws_valid) ?  rf_wdata[31:24]  : 
                            rf_rdata1[31:24];
assign rt_value[31:24] =    (rf_raddr2 == 5'b0 ) ? 8'h00 :
                            ((rf_raddr2 == es_to_ms_bus[68:64]) && es_to_ms_bus[72] && crash_on_es_valid) ? es_forward_data [31:24] :
                            ((rf_raddr2 == ms_to_ws_bus[68:64]) && ms_to_ws_bus[72] && crash_on_ms_valid) ? ms_forward_data [31:24]:
                            ((rf_raddr2 == rf_waddr) && rf_we[3] && crash_on_ws_valid) ?  rf_wdata[31:24]  : 
                            rf_rdata2[31:24];              

assign ds_ready_go =    flush ? 1'b1 : !crash;

/***************************************Update on Lab8**********************************************/
assign ds_ex = ds_valid ? ( inst_syscall | fs_ex | inst_break | reserved_inst | interrupt): 1'b0;
assign ds_excode = ds_valid ? (interrupt ? 5'h0  : 
                               fs_ex ? fs_excode : 
                               ds_excode_temp) : 5'b0;
assign c0_addr      = {rd,c0_sel};
assign inst_valid   = inst_add | inst_addi | inst_addiu | inst_addu | inst_and | inst_andi | inst_div | inst_divu | inst_mult | inst_multu | inst_nor | inst_or | inst_ori | inst_sra | inst_srav | inst_srl | inst_srlv | inst_sll | inst_sllv |
                    inst_slt | inst_slti | inst_sltiu | inst_sltu | inst_sub | inst_subu | inst_xor | inst_xori |
                    inst_bne | inst_beq | inst_bgez | inst_bgezal | inst_bgtz | inst_blez | inst_bltz | inst_bltzal | inst_j | inst_jal | inst_jalr | inst_jr |
                    inst_break | inst_eret | inst_syscall | inst_mfc0 | inst_mtc0 |
                    inst_mfhi | inst_mflo | inst_mtlo | inst_mthi |
                    inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl |inst_lwr |
                    inst_sw | inst_sb | inst_sh  | inst_swl | inst_swr |
                    inst_lui;
assign reserved_inst = ~inst_valid;
assign ds_excode_temp = inst_syscall ? 5'h08 : 
                        inst_break   ? 5'h09 :
                        reserved_inst? 5'h0a : 5'b0;

/***************************************Update on Lab7**********************************************/
assign rs_eq_rt = (rs_value == rt_value);

wire rs_bltz;
wire rs_bgtz;

assign rs_bltz = (rs_value[31] == 1'b1);
assign rs_bgtz = (rs_value[31] == 1'b0) && (rs_value != 32'd0);

assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
                   || inst_bgez && !rs_bltz
                   || inst_bgtz &&  rs_bgtz
                   || inst_bltz &&  rs_bltz
                   || inst_blez && !rs_bgtz
                   || inst_j
                   || inst_jalr
                   || inst_bgezal && !rs_bltz 
                   || inst_bltzal && rs_bltz
                   || inst_jal
                   || inst_jr
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_bltz || inst_blez || inst_bltzal || inst_bgezal) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr)              ? rs_value :
                   /*inst_jal , j*/        {fs_pc[31:28], jidx[25:0], 2'b0} ;
assign ds_branch_op = inst_beq | inst_bne | inst_bgez | inst_blez | inst_bltz | inst_bgtz | inst_bgezal | inst_bltzal | inst_j | inst_jal | inst_jr | inst_jalr;

endmodule
