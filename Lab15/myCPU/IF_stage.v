`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    /*output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,*/

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

    //Lab8
    input         ds_branch_op   ,
    input         eret_flush     ,
    input         ws_ex          ,
    input  [31:0] c0_epc         ,

    //Lab14
    input         tlb_reflush    ,
    output [18:0] s0_vpn2         ,
    output        s0_odd_page     ,
    //output [ 7:0] s0_asid         ,
    input         s0_found        ,
    input  [ 3:0] s0_index        ,
    input  [19:0] s0_pfn          ,
    input  [ 2:0] s0_c            ,
    input         s0_d            ,
    input         s0_v            ,
    //Lab15
    input         ws_tlb_refill 
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
wire         br_stall;// Lab 10 new
reg        bd_done;//..
reg [31:0] br_bus_r;//..
reg [31:0] bd_bus_r;//..
reg [31:0] ex_bus;//..
reg        ex_eret;//..
reg        br_bus_valid;//end
wire       refetch;//Lab14
//Lab15
wire [31:0] phaddr;
wire mapped;
wire [31:0] tlb_nextpc;
wire tlb_refill;
wire tlb_invalid;
reg  tlb_refill_r;
reg  tlb_invalid_r;
reg  fs_pc_mapped;
reg  [31:0] tlb_nextpc_r;

assign {refetch,br_stall,br_taken,br_target} = br_bus;
reg [31:0] refetch_pc;

always@(posedge clk)
begin
    if(reset)
        refetch_pc <= 32'd0;
    else if( refetch )
        refetch_pc <= nextpc;
end

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
wire [ 4:0] fs_excode;
wire        fs_ex;
wire        fs_addr_error;
wire        fs_bd;
wire [31:0] badvaddr_value;
wire        pre_ex;//lab15
wire        pre_addr_error;//lab15

assign fs_bd = fs_ex ? 1'b0 :ds_branch_op;
assign fs_addr_error = (fs_pc[1: 0] != 2'b0) ;
assign pre_addr_error = (nextpc[1: 0] != 2'b0) ;
assign fs_ex = fs_valid ? (fs_addr_error|tlb_invalid_r|tlb_refill_r):1'b0;
assign pre_ex = tlb_refill|tlb_invalid|pre_addr_error;
assign fs_excode = fs_ex ? ((tlb_refill_r | tlb_invalid_r) ? 5'h02 :5'h04):5'h0;
assign badvaddr_value = fs_addr_error ? fs_pc :
                        (tlb_invalid_r|tlb_refill_r) ? tlb_nextpc_r : 32'd0;
assign fs_to_ds_bus = {
                       tlb_refill_r,   //103:103
                       badvaddr_value,//102:71
                       fs_excode, //70:66
                       fs_ex  ,   //65:65
                       fs_bd  ,   //64:64
                       fs_inst ,
                       fs_pc   };

// pre-IF stage
assign to_fs_valid  = ~reset & ((inst_sram_addr_ok & inst_sram_req) || pre_ex);//lab15
assign seq_pc       = fs_pc + 3'h4;

//modified in Lab15
assign tlb_nextpc   = 
                      ex_eret    ? ex_bus:
                      (br_bus_valid & bd_done) ? br_bus_r: 
                      (br_bus_valid & ~bd_done) ?  bd_bus_r :seq_pc;
// IF stage

assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if(eret_flush | ws_ex | tlb_reflush)
    begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid ;
    end
    
    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        if(tlb_refill|tlb_invalid)
            fs_pc <= tlb_nextpc;
        else
            fs_pc <= nextpc;
    end
    
end

//*************************** UPDATE ON LAB10 ****************************//
reg request_control;//make req = 0 during addr_ok to data_ok 
reg [31:0] inst_bus;
reg        inst_bus_valid;
reg        cancel;

assign inst_sram_addr = (inst_sram_req & inst_sram_addr_ok)?nextpc:32'd0;
assign inst_sram_wr  = 1'b0         ;
assign inst_sram_size = 2'b10       ;
assign inst_sram_wstrb = 4'h0       ;
assign inst_sram_wdata = 32'b0      ;

assign fs_ready_go    = fs_ex ? 1'b1:
                        (inst_sram_data_ok | inst_bus_valid) & !cancel;//Lab15
//出例外 拉高 之前就该写的
assign inst_sram_req = !br_stall & !reset & fs_allowin & !request_control & !fs_ex & !pre_ex; 
always @(posedge clk)
begin
    if(reset)
    begin
        request_control <= 1'b0 ;
    end
    else if (eret_flush | ws_ex |tlb_reflush)
    begin
        request_control <= 1'b0 ;
    end
    else if (request_control & inst_sram_data_ok)
    begin
        request_control <= 1'b0 ;
    end
    else if (inst_sram_req & inst_sram_addr_ok)
    begin
        request_control <= 1'b1 ;
    end
    
end

always @(posedge clk)
begin
    if(reset)
    begin
        inst_bus_valid <= 1'b0;
    end
     else if (ws_ex|eret_flush |tlb_reflush) 
    begin
        inst_bus_valid <= 1'b0;
    end
    
    else if(fs_to_ds_valid & ds_allowin)
    begin
        inst_bus_valid <= 1'b0;
    end
    else if(fs_valid & inst_sram_data_ok & !inst_bus_valid & !cancel)
    begin
        inst_bus_valid <= 1'b1;
    end

end
always @(posedge clk)
begin
    if(fs_valid & inst_sram_data_ok)
    begin
        inst_bus <= inst_sram_rdata;
    end 
end

always @(posedge clk)
begin
    if(reset)
    begin
        cancel <= 1'b0 ;
    end
    else if((ws_ex|eret_flush |tlb_reflush)&((to_fs_valid & !pre_ex) | (!fs_allowin & !fs_ready_go))) 
    //valid 和 ready_go用的同一个信号 所以需要保证为高的时候拉低cancel
    begin
        cancel <= 1'b1;
    end
    else if (cancel & inst_sram_data_ok)
    begin
        cancel <= 1'b0 ;
    end
    
end
always @(posedge clk)
begin
    if(reset)
    begin
        ex_eret <= 1'b0;
    end
    else if(eret_flush | ws_ex | tlb_reflush)
    begin
        ex_eret <= 1'b1;
    end
    else if(to_fs_valid && fs_allowin)
    begin
        ex_eret <= 1'b0;
    end
end
always @(posedge clk)
begin
    if(eret_flush)
        ex_bus <= c0_epc;
    else if (ws_ex & ws_tlb_refill)
        ex_bus <= 32'hbfc00200;
    else if (ws_ex & !ws_tlb_refill)
        ex_bus <= 32'hbfc00380;
    else if (tlb_reflush)
        ex_bus <= refetch_pc;
end

always @(posedge clk)
begin
    if(reset)
    begin
        br_bus_valid <= 1'b0 ;
    end
    else if (ws_ex|eret_flush | tlb_reflush)
    begin
        br_bus_valid <= 1'b0 ;
    end
    else if (br_taken & !br_stall)
    begin
        br_bus_valid <= 1'b1;
    end
    else if (to_fs_valid & fs_allowin & bd_done)
    begin
        br_bus_valid <= 1'b0;
    end
end

always @(posedge clk) 
begin
    if(br_taken & !br_stall)
    begin
        br_bus_r <= br_target;
    end   
end
always @(posedge clk) 
begin
    
    if(br_taken & !br_stall) 
    begin
        bd_bus_r <= nextpc;
    end
end
always @(posedge clk)
begin
    if(reset)
    begin
        bd_done <= 1'b0;
    end
    else if (br_bus_valid & fs_valid)
    begin
        bd_done <= 1'b1;
    end
    else if (to_fs_valid & fs_allowin & bd_done)
    begin
        bd_done <= 1'b0;
    end
end

assign fs_inst         = fs_ex ? 32'b0 : 
                        inst_bus_valid ? inst_bus : inst_sram_rdata;
//*************************** UPDATE ON LAB14 ****************************//
assign s0_vpn2 = tlb_nextpc[31:13];
assign s0_odd_page = tlb_nextpc[12];
               
assign phaddr =  {s0_pfn, tlb_nextpc[11:0]} ;
assign mapped = (tlb_nextpc[31:30] != 2'b10); 
assign nextpc = mapped ? phaddr : tlb_nextpc;

always @(posedge clk)
begin
    if (reset) 
        tlb_invalid_r <= 1'b0;
    else if (to_fs_valid && fs_allowin) 
        tlb_invalid_r <= tlb_invalid;
end
always @(posedge clk)
begin
    if (reset) 
        tlb_refill_r <= 1'b0;
    else if (to_fs_valid && fs_allowin) 
        tlb_refill_r <= tlb_refill;
end
always @(posedge clk)
begin
    if (reset) 
        tlb_nextpc_r <= 32'd0;
    else if (to_fs_valid && fs_allowin) 
        tlb_nextpc_r <= tlb_nextpc;
end

assign tlb_refill  = mapped & !s0_found;
assign tlb_invalid = mapped & s0_found & !s0_v;

endmodule
