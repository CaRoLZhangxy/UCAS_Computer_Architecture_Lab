`include "mycpu.h"
//////////////////////////////////////////////////////////////////////////////////
// Company: 443有限公司
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: SRAM-AXI-BRIDGE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define INIT 	4'b0001
`define ALLOC 	4'b0010
`define WAIT 	4'b0100
`define FINISH 	4'b1000



module sram_axi_bridge(
	input				clk,
	input				resetn,
    //inst sram-like 
    input				inst_sram_req,
	input				inst_sram_wr,
	input  [1:0]		inst_sram_size,
	input  [3:0]		inst_sram_wstrb,
	input  [31:0]		inst_sram_addr,
	input  [31:0]		inst_sram_wdata,
	output [31:0]		inst_sram_rdata,
	output				inst_sram_addr_ok,
	output				inst_sram_data_ok,
    //data sram-like 
	input				data_sram_req,
	input				data_sram_wr,
	input  [1:0]		data_sram_size,
	input  [3:0]		data_sram_wstrb,
	input  [31:0]		data_sram_addr,
	input  [31:0]		data_sram_wdata,
	output [31:0]		data_sram_rdata,
	output 				data_sram_addr_ok,
	output				data_sram_data_ok,
    //axi
    //alloc read        using   ar
	output [3:0]		arid,
	output [31:0]		araddr,
	output [7:0]		arlen,
	output [2:0]		arsize,
	output [1:0]		arburst,
	output [1:0]		arlock,
	output [3:0]		arcache,
	output [2:0]		arprot,
	output				arvalid,
	input				arready,
    //read response     using   r              
	input [3:0]			rid,
	input [31:0]		rdata,
	input [1:0]			rresp,
	input				rlast,
	input				rvalid,
	output				rready,
    //alloc write       using   aw           
	output [3:0]		awid,
	output [31:0]		awaddr,
	output [7:0]		awlen,
	output [2:0]		awsize,
	output [1:0]		awburst,
	output [1:0]		awlock,
	output [3:0]		awcache,
	output [2:0]		awprot,
	output				awvalid,
	input				awready,
    //write data        using   w          
	output [3:0]		wid,
	output [31:0]		wdata,
	output [3:0]		wstrb,
	output				wlast,
	output				wvalid,
	input				wready,
    //write response    using   b              
	input [3:0]			bid,
	input [1:0]			bresp,
	input				bvalid,
	output 				bready
);

reg  [ 3:0] r_status; // 
reg         r_isdata;   // 0-inst 1-data
reg  [ 2:0] r_size;
reg  [31:0] r_addr;

reg  [ 3:0] w_status; 
reg         w_isdata;   // 0-inst 1-data
reg  [ 2:0] w_size;
reg  [31:0] w_addr;
reg  [31:0] w_data;
reg  [ 3:0] w_strb;
reg  [31:0]	data_sram_rdata_r;
reg  [31:0]	inst_sram_rdata_r;
reg         wr_crash;
reg         rw_crash;
reg         en_arvalid;
reg         en_awvalid;
reg         en_wvalid;

always @(posedge clk) begin
    if(!resetn) 
        r_status    <= `INIT;
    else if((r_status == `INIT)&&((data_sram_req && !data_sram_wr)||(inst_sram_req && !inst_sram_wr)))
        r_status    <=  `ALLOC;
    else if((r_status == `ALLOC)&&(arvalid && arready))
        r_status    <=  `WAIT;
    else if((r_status == `WAIT)&&(rvalid ))
        r_status    <=  `FINISH;
    else if((r_status == `FINISH)&&((r_isdata != w_isdata )|| (w_status != `FINISH)))
        r_status    <=  `INIT; 
end   

always @(posedge clk) begin
    if(!resetn) 
        r_isdata      <= 1'b0;
    else if((r_status == `INIT)&&(data_sram_req && !data_sram_wr))
        r_isdata      <=  1'b1;
    else if((r_status == `INIT)&&(inst_sram_req && !inst_sram_wr))
        r_isdata      <=  1'b0;   
end

always @(posedge clk) begin
    if(!resetn) 
        r_size      <= 3'd0;
    else if((r_status == `ALLOC)&&(r_isdata && data_sram_addr_ok && !en_arvalid))
        r_size      <= data_sram_size;
    else if((r_status == `ALLOC)&&(!r_isdata && inst_sram_addr_ok && !en_arvalid))
        r_size      <= inst_sram_size;
end 

always @(posedge clk) begin
    if(!resetn) 
        r_addr      <= 32'd0;
    else if((r_status == `ALLOC)&&(r_isdata && data_sram_addr_ok && !en_arvalid))
        r_addr      <= data_sram_addr;
    else if((r_status == `ALLOC)&&(!r_isdata && inst_sram_addr_ok && !en_arvalid))
        r_addr      <= inst_sram_addr;
end 

always @(posedge clk) begin
    if(!resetn) 
        en_arvalid  <= 1'd0;
    else if((r_status == `ALLOC)&&((data_sram_req && !data_sram_wr)||(inst_sram_req && !inst_sram_wr))&& !en_arvalid)
        en_arvalid  <= 1'b1;
    else if((r_status == `ALLOC)&&(arvalid && arready))
        en_arvalid  <= 1'b0;
end 

always @(posedge clk) begin
    if(!resetn) 
        wr_crash    <= 1'd0;
    else if((r_status == `ALLOC)&&((data_sram_req && !data_sram_wr)||(inst_sram_req && !inst_sram_wr))&& !en_arvalid)
        wr_crash    <= (w_status==`ALLOC||w_status==`WAIT);
    else if((r_status == `ALLOC)&& wr_crash)
        wr_crash    <= (w_status==`ALLOC||w_status==`WAIT);
end 

always @(posedge clk) begin
    if(!resetn) 
        inst_sram_rdata_r   <= 32'd0;
    else if((r_status == `WAIT)&&(rvalid && !r_isdata))
        inst_sram_rdata_r   <= rdata;
end 

always @(posedge clk) begin
    if(!resetn) 
        data_sram_rdata_r   <= 32'd0;
    else if((r_status == `WAIT)&&(rvalid && r_isdata))
        data_sram_rdata_r   <= rdata;
end 
assign inst_sram_rdata = inst_sram_rdata_r;
assign data_sram_rdata = data_sram_rdata_r;

always @(posedge clk) begin
    if(!resetn) 
        w_status    <= `INIT;
    else if((w_status == `INIT)&&((data_sram_req && data_sram_wr)||(inst_sram_req && inst_sram_wr)))
        w_status    <=  `ALLOC;
    else if((w_status == `ALLOC)&&((awvalid && awready && wvalid && wready) || (awvalid && awready && !wvalid) || (wvalid && wready && !awvalid)))
        w_status    <=  `WAIT;
    else if((w_status == `WAIT)&& bvalid ) 
        w_status    <=  `FINISH;
    else if((w_status == `FINISH))
        w_status    <=  `INIT; 
end 
always @(posedge clk) begin
    if(!resetn) 
        w_isdata      <= 1'b0;
    else if((w_status == `INIT)&&(data_sram_req && data_sram_wr))
        w_isdata      <=  1'b1;
    else if((w_status == `INIT)&&(inst_sram_req && inst_sram_wr))
        w_isdata      <=  1'b0;   
end

always @(posedge clk) begin
    if(!resetn) 
        w_size      <= 3'd0;
    else if((w_status == `ALLOC)&& (!en_awvalid && !en_wvalid) && (w_isdata && data_sram_addr_ok))
        w_size      <= data_sram_size;
    else if((w_status == `ALLOC)&& (!en_awvalid && !en_wvalid) && (!w_isdata && inst_sram_addr_ok))
        w_size      <= inst_sram_size;
end 

always @(posedge clk) begin
    if(!resetn) 
        w_addr      <= 32'd0;
    else if((w_status == `ALLOC)&& (!en_awvalid && !en_wvalid) && (w_isdata && data_sram_addr_ok))
        w_addr      <= data_sram_addr;
    else if((w_status == `ALLOC)&& (!en_awvalid && !en_wvalid) && (!w_isdata && inst_sram_addr_ok))
        w_addr      <= inst_sram_addr;
end 

always @(posedge clk) begin
    if(!resetn) 
        w_strb      <= 4'd0;
    else if((w_status == `ALLOC)&& (!en_awvalid && !en_wvalid) && (w_isdata && data_sram_addr_ok))
        w_strb      <= data_sram_wstrb;
    else if((w_status == `ALLOC)&& (!en_awvalid && !en_wvalid) && (!w_isdata && inst_sram_addr_ok))
        w_strb      <= inst_sram_wstrb;
end 

always @(posedge clk) begin
    if(!resetn) 
        w_data      <= 32'd0;
    else if((w_status == `ALLOC)&& (!en_awvalid && !en_wvalid) && (w_isdata && data_sram_addr_ok))
        w_data      <= data_sram_wdata;
    else if((w_status == `ALLOC)&& (!en_awvalid && !en_wvalid) && (!w_isdata && inst_sram_addr_ok))
        w_data      <= inst_sram_wdata;
end 

always @(posedge clk) begin
    if(!resetn) 
        rw_crash    <= 1'd0;
    else if((w_status == `ALLOC)&&(!en_awvalid && !en_wvalid) && ((w_isdata && data_sram_addr_ok)||(!w_isdata && inst_sram_addr_ok)))
        rw_crash    <= (r_status==`ALLOC||r_status==`WAIT);
    else if((w_status == `ALLOC)&& rw_crash)
        rw_crash    <= (r_status==`ALLOC||r_status==`WAIT);
end 

always @(posedge clk) begin
    if(!resetn) 
        en_awvalid  <= 1'd0;
    else if((w_status == `ALLOC)&&(!en_awvalid && !en_wvalid) && ((w_isdata && data_sram_addr_ok)||(!w_isdata && inst_sram_addr_ok)))
        en_awvalid  <= 1'd1;
    else if((w_status == `ALLOC)&& (awvalid && awready))
        en_awvalid  <= 1'd0;
end 

always @(posedge clk) begin
    if(!resetn) 
        en_wvalid   <= 1'd0;
    else if((w_status == `ALLOC)&&(!en_awvalid && !en_wvalid) && ((w_isdata && data_sram_addr_ok)||(!w_isdata && inst_sram_addr_ok)))
        en_wvalid   <= 1'd1;
    else if((w_status == `ALLOC)&& (wvalid && wready))
        en_wvalid   <= 1'd0;
end 

assign inst_sram_addr_ok = (!wr_crash) && (r_status == `ALLOC && !r_isdata  && !arvalid  ) ||
                      (w_status == `ALLOC && !w_isdata  && !awvalid && !wvalid  );

assign inst_sram_data_ok = (r_status == `FINISH && !r_isdata ) ||
                      (w_status == `FINISH && !w_isdata ) ;

assign data_sram_addr_ok = (!wr_crash) && (r_status == `ALLOC && r_isdata  && !arvalid  ) ||
                      (w_status == `ALLOC && w_isdata  && !awvalid && !wvalid  );

assign data_sram_data_ok = (r_status == `FINISH && r_isdata) ||
                      (w_status == `FINISH && w_isdata) ;

assign araddr  = r_addr;
assign arsize  = {1'b0, r_size[2] ? 2'b10 : r_size[1:0]};
assign arvalid = en_arvalid && !wr_crash;
assign rready  = (r_status == `WAIT);

assign awaddr  = w_addr;
assign awsize  = {1'b0, w_size[2] ? 2'b10 : w_size[1:0]};
assign wdata   = w_data;
assign awvalid = en_awvalid && !rw_crash;
assign wvalid  = en_wvalid  && !rw_crash;
assign bready  = (w_status == `WAIT);

assign arid    = (r_status == `ALLOC)&&(r_isdata==1'b1) ;
assign rid     = (r_status == `ALLOC)&&(r_isdata==1'b1) ;
assign arlen   = 8'd0 ;
assign arburst = 2'b01;
assign arlock  = 2'd0 ;
assign arcache = 4'd0 ;
assign arprot  = 3'd0 ;

assign awid    = 4'd0 ;
assign awlen   = 8'd0 ;
assign awburst = 2'b01;
assign awlock  = 2'd0 ;
assign awcache = 4'd0 ;
assign awprot  = 3'd0 ;

assign wid     = 4'd1 ;
assign wlast   = 1'b1 ;
assign wstrb   = w_strb;
endmodule