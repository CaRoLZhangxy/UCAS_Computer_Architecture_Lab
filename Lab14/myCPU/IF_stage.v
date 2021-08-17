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
    input  [ 3:0] s0_c            ,
    input         s0_d            ,
    input         s0_v            
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
wire        fs_bd;
wire [31:0] badvaddr_value;

assign fs_bd = fs_ex ? 1'b0 :ds_branch_op;
assign fs_ex = fs_valid ? (fs_pc[1: 0] != 2'b0) : 1'b0 ;
assign fs_excode = fs_ex ? 5'h04 : 5'h0;
assign badvaddr_value = fs_pc;
assign fs_to_ds_bus = {badvaddr_value,//102:71
                       fs_excode, //70:66
                       fs_ex  ,   //65:65
                       fs_bd  ,   //64:64
                       fs_inst ,
                       fs_pc   };

// pre-IF stage
assign to_fs_valid  = ~reset & inst_sram_addr_ok & inst_sram_req;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = ex_eret    ? ex_bus:
                      (br_bus_valid & bd_done) ? br_bus_r: 
                      (br_bus_valid & ~bd_done) ?  bd_bus_r :seq_pc;
//assign bd_done = ds_to_es_valid;
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
        fs_pc <= nextpc;
    end
end

/*assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;*/
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

assign fs_ready_go    = (inst_sram_data_ok | inst_bus_valid) & !cancel;

assign inst_sram_req = !br_stall & !reset & fs_allowin & !request_control & !fs_ex; 
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
    else if((ws_ex|eret_flush |tlb_reflush)&(to_fs_valid | (!fs_allowin & !fs_ready_go))) 
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
    else if (ws_ex)
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

assign fs_inst         = inst_bus_valid ? inst_bus : inst_sram_rdata;
//*************************** UPDATE ON LAB14 ****************************//
assign s0_vpn2 = nextpc[31:13];
assign s0_odd_page = nextpc[12];
endmodule
