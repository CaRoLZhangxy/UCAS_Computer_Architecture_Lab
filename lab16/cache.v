module cache( 
//global
input         clk,
input         resetn, 
//CPU<->CACHE
input         valid,
input         op,//1 write 0 read
input [ 7:0]  index, //addr[11:4]
input [19:0]  tag, //pfn + addr[12]
input [ 3:0]  offset, //addr[3:0]
input [ 3:0]  wstrb,
input [31:0]  wdata,
output        addr_ok,
output        data_ok,
output[31:0]  rdata,
//CACHE<->AXI-BRIDGE
//read
output        rd_req,
output[ 2:0]  rd_type,//3'b000-BYTE  3'b001-HALFWORD 3'b010-WORD 3'b100-cache-row
output[31:0]  rd_addr,
input         rd_rdy,
input         ret_valid,
input [ 1:0]  ret_last,
input [31:0]  ret_data,
//write
output        wr_req,
output[ 2:0]  wr_type,
output[31:0]  wr_addr,
output[ 3:0]  wr_wstrb,
output[127:0] wr_data,       
input         wr_rdy//wr_req_r can be accepted, actually nonsense in inst_cache

);  
//state machine
reg [4:0] curstate;
reg [4:0] nxtstate;
parameter IDLE 		= 5'b00001;
parameter LOOKUP 	= 5'b00010;
parameter MISS 		= 5'b00100;
parameter REPLACE 	= 5'b01000;
parameter REFILL 	= 5'b10000;
parameter INIT 		= 16'h1; //初始值
parameter COFF 		= 16'h400; //生成多项式
always@(posedge clk) begin
	if(~resetn) begin
		curstate <= IDLE;
	end 
	else begin
		curstate <= nxtstate;
	end
end
//STATE TRANSFORMATION
always@(*) begin
case(curstate)
	IDLE:
	begin
		if(valid)
			nxtstate = LOOKUP;        
		else//用busy_tag实现的阻塞
			nxtstate = curstate;
	end 
	LOOKUP:
	begin
		if(cache_hit)
			nxtstate = IDLE;
		else
			nxtstate = MISS;
	end
	MISS:
	begin
		if(wr_rdy)
			nxtstate = REPLACE;
		else if(((Way1_Dram_rdata == 1)&replace_way | (Way1_Dram_rdata == 1)&~replace_way))
			nxtstate = REPLACE;
		else
			nxtstate = curstate;
	end
	REPLACE:
	begin
		if(rd_rdy)
			nxtstate = REFILL;
		else
			nxtstate = curstate;
	end
	REFILL:
	begin
		if(ret_last)
			nxtstate = IDLE;        
		else
			nxtstate = curstate;
	end
	default:
		nxtstate = IDLE;
endcase
end 

//Request buffer
wire          op_r;//1 write 0 read
wire  [ 7:0]  index_r; //addr[11:4]
wire  [19:0]  tag_r; //pfn + addr[12]
wire  [ 3:0]  offset_r; //addr[3:0]
wire  [ 3:0]  wstrb_r;
wire  [31:0]  wdata_r;
reg   [68:0]  Request_buffer;
reg           busy_tag;
reg	  [255:0] cache_D0;
reg   [255:0] cache_D1;
reg   [127:0] replace_data_r;
/************LSFR***************/
reg [15:0]  dout;
reg [15:0]  dout_next;
always @ (posedge clk )begin
	if(!resetn)       dout <=  INIT;
	else          	  dout <=  dout_next;
end
integer i;
always@(*)
begin
dout_next[0] <= dout[2];
for(i=1; i<16; i=i+1)
	if(COFF[16-i])        dout_next[i] <= dout[i-1]^dout[2];
	else                  dout_next[i] <= dout[i-1];
end
assign replace_way = dout[0];
/*************LSFR finish*************/
always@(posedge clk)begin
	if(!resetn) begin
		Request_buffer <= 0;
		busy_tag <= 0;
	end
	if(busy_tag & data_ok) begin
		Request_buffer <= 0;
		busy_tag <= 0;
	end
	if(curstate == IDLE & valid) begin//来了一拍有效数据
		Request_buffer <= {op,index,tag,offset,wstrb,wdata};
		busy_tag <= 1;
	end
end
assign {
		op_r,
		index_r,
		tag_r,
		offset_r,
		wstrb_r,
		wdata_r
		}=Request_buffer;

wire          	replace_way;
wire [1:0]	  	row_off;
wire [127:0]  	replace_data;  
wire [19:0]    	replace_addr;


assign row_off=offset_r[3:2];


assign addr_ok = (curstate == LOOKUP)|(curstate==IDLE & !valid);
									
									

reg data_ok_valid;
always@(posedge clk) begin
	if(!resetn)
		data_ok_valid <= 0;
	else if(valid)
		data_ok_valid <= 1;
	else if(data_ok)
		data_ok_valid <= 0;
end
assign data_ok = (curstate == IDLE & data_ok_valid);
//assign data_ok = (curstate == LOOKUP & cache_hit)|(curstate == LOOKUP & op_r);
assign rd_req = curstate == REPLACE;
assign rd_type = 3'b100;  
assign rd_addr = {tag_r,index_r,4'b00};


reg wr_req_r;
always@(posedge clk) begin
	if(!resetn)
		wr_req_r <= 0;
	else if((curstate == MISS & nxtstate == REPLACE) & !wr_rdy)
	//else if((curstate == MISS & nxtstate == REPLACE) ) //for bug commit
		wr_req_r <= 1;
	else if(wr_rdy)
		wr_req_r <= 0;
end
assign wr_req = wr_req_r;
assign wr_type = 3'b100;
assign wr_addr = {replace_addr,index_r,4'b00};
assign wr_wstrb = 4'b1111;
assign wr_data = replace_data;	
reg [1:0] rd_cnt;
always @(posedge clk) begin
	if(!resetn) begin
		rd_cnt <= 2'b00;
	end
	else if(ret_valid) begin
		rd_cnt <= rd_cnt + 2'b01;
	end
end
reg [31:0] data_buffer;
always@(posedge clk) begin
	if(!resetn) begin
		data_buffer <= 0;
	end
	else if(curstate == LOOKUP & cache_hit)
		data_buffer <= load_data;
	else if(row_off == 2'b00 & rd_cnt == 2'b00 & ret_valid)
		data_buffer <= ret_data;
	else if(row_off == 2'b01 & rd_cnt == 2'b01 & ret_valid)
		data_buffer <= ret_data;
	else if(row_off == 2'b10 & rd_cnt == 2'b10 & ret_valid)
		data_buffer <= ret_data;
	else if(row_off == 2'b11 & rd_cnt == 2'b11 & ret_valid)
		data_buffer <= ret_data;
end
assign rdata = data_buffer;
/*******************************TAGV RAM********************************/				
//Way0_TAGV
wire 	   Way0_TAGV_we;
wire [7:0] Way0_TAGV_addr;
wire [20:0]Way0_TAGV_wdata;
wire [20:0]Way0_TAGV_rdata;
//Way1_TAGV
wire  	   Way1_TAGV_we;
wire [7:0] Way1_TAGV_addr;
wire [20:0]Way1_TAGV_wdata;
wire [20:0]Way1_TAGV_rdata;
// hit tag
wire         way0_hit;
wire         way1_hit;
wire         cache_hit;
assign Way0_TAGV_addr 	= busy_tag? index_r : valid? index :0;
assign Way1_TAGV_addr 	= busy_tag? index_r : valid? index :0;
assign Way0_TAGV_wdata 	= {tag_r,1'b1};
assign Way1_TAGV_wdata 	= {tag_r,1'b1};
assign Way0_TAGV_we 	= (curstate == REFILL & !replace_way)? 1'b1:0;
assign Way1_TAGV_we 	= (curstate == REFILL & replace_way)? 1'b1:0;

TAGV_ram my_Way0_TAGV(
	.clka(clk),    // input wire clka
	.wea(Way0_TAGV_we),      // 1
	.addra(Way0_TAGV_addr),  // [7:0]
	.dina(Way0_TAGV_wdata),  // [20:0]
	.douta(Way0_TAGV_rdata)  // [20:0]
);

TAGV_ram my_Way1_TAGV(
	.clka(clk),    // input wire clka
	.wea(Way1_TAGV_we),      // 1
	.addra(Way1_TAGV_addr),  // [7:0]
	.dina(Way1_TAGV_wdata),  // [20:0]
	.douta(Way1_TAGV_rdata)  // [20:0]
);




wire         way0_v;
wire         way1_v;
wire [19:0]  way0_tag;
wire [19:0]  way1_tag;
assign way0_tag = Way0_TAGV_rdata[20:1];
assign way1_tag = Way1_TAGV_rdata[20:1];
assign way0_v   = Way0_TAGV_rdata[0];
assign way1_v   = Way1_TAGV_rdata[0];
assign way0_hit = way0_v && (way0_tag == tag_r );
assign way1_hit = way1_v && (way1_tag == tag_r );
assign cache_hit = way0_hit || way1_hit;
assign replace_addr = replace_way? way1_tag : way0_tag;

/***************************DIRTY RAM*************************/
//dirty_ram_0
wire [7:0]   Way1_Dram_addr;
wire         Way1_Dram_we;
wire         Way1_Dram_wdata;
wire         Way1_Dram_rdata;
//dirty_ram_1
wire [7:0]   Way0_Dram_addr;
wire         Way0_Dram_we;
wire         Way0_Dram_wdata;
wire         Way0_Dram_rdata;

assign Way0_Dram_addr 	= busy_tag?index_r: valid? index: 0;
assign Way1_Dram_addr 	= busy_tag?index_r: valid? index: 0;
assign Way0_Dram_wdata 	= (op_r == 1);
assign Way1_Dram_wdata 	= (op_r == 1);
assign Way0_Dram_we 	= (curstate == LOOKUP & way0_hit & op_r ) | (curstate == REFILL & !replace_way & op_r );
assign Way1_Dram_we 	= (curstate == LOOKUP & way1_hit & op_r ) | (curstate == REFILL & replace_way & op_r );

Cache_D_Ram dirty_ram_0(
	.clka(clk),    // input wire clk
	.wea(Way0_Dram_we),      // 1
	.addra(Way0_Dram_addr),  // [7:0]
	.dina(Way0_Dram_wdata),  // 1
	.douta(Way0_Dram_rdata)  // 1
);

Cache_D_Ram dirty_ram_1(
	.clka(clk),    // input wire clk
	.wea(Way1_Dram_we),      // 1
	.addra(Way1_Dram_addr),  // [7:0]
	.dina(Way1_Dram_wdata),  // 1
	.douta(Way1_Dram_rdata)  // 1
);

							
/*****************8 BANK RAM************************/
wire [3:0] Way0_bank0_en;
wire [7:0] Way0_bank0_addr;
wire [31:0] Way0_bank0_wdata;
wire [31:0] Way0_bank0_rdata;

wire [3:0] Way0_bank1_en;
wire [7:0] Way0_bank1_addr;
wire [31:0] Way0_bank1_wdata;
wire [31:0] Way0_bank1_rdata;

wire [3:0] Way0_bank2_en;
wire [7:0] Way0_bank2_addr;
wire [31:0] Way0_bank2_wdata;
wire [31:0] Way0_bank2_rdata;

wire [3:0] Way0_bank3_en;
wire [7:0] Way0_bank3_addr;
wire [31:0] Way0_bank3_wdata;
wire [31:0] Way0_bank3_rdata;

wire [3:0] Way1_bank0_en;
wire [7:0] Way1_bank0_addr;
wire [31:0] Way1_bank0_wdata;
wire [31:0] Way1_bank0_rdata;

wire [3:0] Way1_bank1_en;
wire [7:0] Way1_bank1_addr;
wire [31:0] Way1_bank1_wdata;
wire [31:0] Way1_bank1_rdata;

wire [3:0] Way1_bank2_en;
wire [7:0] Way1_bank2_addr;
wire [31:0] Way1_bank2_wdata;
wire [31:0] Way1_bank2_rdata;

wire [3:0] Way1_bank3_en;
wire [7:0] Way1_bank3_addr;
wire [31:0] Way1_bank3_wdata;
wire [31:0] Way1_bank3_rdata;

wire [31:0]   way0_load_word;
wire [31:0]   way1_load_word;
wire [31:0]   load_data;

assign way0_load_word = ({32{offset_r == 4'b0000}} & Way0_bank0_rdata) |
						({32{offset_r == 4'b0100}} & Way0_bank1_rdata) |
						({32{offset_r == 4'b1000}} & Way0_bank2_rdata) |
						({32{offset_r == 4'b1100}} & Way0_bank3_rdata);
assign way1_load_word = ({32{offset_r == 4'b0000}} & Way1_bank0_rdata) |
						({32{offset_r == 4'b0100}} & Way1_bank1_rdata) |
						({32{offset_r == 4'b1000}} & Way1_bank2_rdata) |
						({32{offset_r == 4'b1100}} & Way1_bank3_rdata);
assign load_data 	  = {32{way0_hit}} & way0_load_word
						|{32{way1_hit}} & way1_load_word;
assign replace_data   = replace_way? {Way1_bank3_rdata,Way1_bank2_rdata,Way1_bank1_rdata,Way1_bank0_rdata}:
									 {Way0_bank3_rdata,Way0_bank2_rdata,Way0_bank1_rdata,Way0_bank0_rdata};




wire [31:0] cache_write_data;
assign cache_write_data[31:24] 	= wstrb_r[3] ? wdata_r[31:24] 	: ret_data[31:24];
assign cache_write_data[23:16] 	= wstrb_r[2] ? wdata_r[23:16] 	: ret_data[23:16];
assign cache_write_data[15:8] 	= wstrb_r[1] ? wdata_r[15:8] 	: ret_data[15:8];
assign cache_write_data[7:0] 	= wstrb_r[0] ? wdata_r[7:0] 	: ret_data[7:0];

assign Way0_bank0_en 	=  	(curstate == LOOKUP & way0_hit &row_off == 2'b00 & op_r)?wstrb_r://hit store
						   	(curstate == REFILL & rd_cnt == 2'b00 & ret_valid & !replace_way)?4'b1111:0;
assign Way0_bank0_addr 	= 	(curstate == IDLE)?index:index_r;
assign Way0_bank0_wdata = 	(curstate == LOOKUP & cache_hit & row_off == 2'b00)?wdata_r://hit store
							(curstate == REFILL)& (row_off == 2'b00)? cache_write_data:0;
								
assign Way0_bank1_en 	=  	(curstate == LOOKUP & way0_hit &row_off == 2'b01 & op_r)?wstrb_r://hit store
							(curstate == REFILL & rd_cnt == 2'b01 & ret_valid & !replace_way)?4'b1111:0;
assign Way0_bank1_addr 	= 	(curstate == IDLE)?index:index_r;
assign Way0_bank1_wdata = 	(curstate == LOOKUP & cache_hit & row_off == 2'b01)?wdata_r://hit store
							(curstate == REFILL)& (row_off == 2'b01)? cache_write_data:0;
									
assign Way0_bank2_en 	=  	(curstate == LOOKUP & way0_hit &row_off == 2'b10 & op_r)?wstrb_r://hit store
							(curstate == REFILL & rd_cnt == 2'b10 & ret_valid & !replace_way)?4'b1111:0;
assign Way0_bank2_addr 	= 	(curstate == IDLE)?index:index_r;
assign Way0_bank2_wdata = 	(curstate == LOOKUP & cache_hit & row_off == 2'b10)?wdata_r://hit store
							(curstate == REFILL)&(row_off == 2'b10)? cache_write_data:0;
								
assign Way0_bank3_en 	=   (curstate == LOOKUP & way0_hit &row_off == 2'b11 & op_r)?wstrb_r://hit store
							(curstate == REFILL & rd_cnt == 2'b11 & ret_valid & !replace_way)?4'b1111:0;								
assign Way0_bank3_addr 	= 	(curstate == IDLE)?index:index_r;
assign Way0_bank3_wdata = 	(curstate == LOOKUP & cache_hit & row_off == 2'b11)?wdata_r://hit store
							(curstate == REFILL)& (row_off == 2'b11)? cache_write_data:0;
								
assign Way1_bank0_en 	=  	(curstate == LOOKUP & way1_hit &row_off == 2'b00 & op_r)?wstrb_r://hit store
							(curstate == REFILL & rd_cnt == 2'b00 & ret_valid & replace_way)?4'b1111:0;
assign Way1_bank0_addr 	= 	(curstate == IDLE)?index:index_r;
assign Way1_bank0_wdata = 	(curstate == LOOKUP & cache_hit & row_off == 2'b00)?wdata_r://hit store
							(curstate == REFILL)& (row_off == 2'b00)? cache_write_data:0;
								
assign Way1_bank1_en 	=  	(curstate == LOOKUP & way1_hit &row_off == 2'b01 & op_r)?wstrb_r://hit store
							(curstate == REFILL & rd_cnt == 2'b01 & ret_valid & replace_way)?4'b1111:0;
assign Way1_bank1_addr 	= 	(curstate == IDLE)?index:index_r;
assign Way1_bank1_wdata = 	(curstate == LOOKUP & cache_hit & row_off == 2'b01)?wdata_r://hit store
							(curstate == REFILL)& (row_off == 2'b01)? cache_write_data:0;
									
assign Way1_bank2_en 	=  	(curstate == LOOKUP & way1_hit &row_off == 2'b10 & op_r)?wstrb_r://hit store
							(curstate == REFILL & rd_cnt == 2'b10 & ret_valid & replace_way)?4'b1111:0;//refill								
assign Way1_bank2_addr	= 	(curstate == IDLE)?index:index_r;
assign Way1_bank2_wdata = 	(curstate == LOOKUP & cache_hit & row_off == 2'b10)?wdata_r://hit store
							(curstate == REFILL)& (row_off == 2'b10)? cache_write_data:0;
								
assign Way1_bank3_en	=  	(curstate == LOOKUP & way1_hit &row_off == 2'b11 & op_r)?wstrb_r://hit store
							(curstate == REFILL & rd_cnt == 2'b11 & ret_valid & replace_way)?4'b1111:0;//refill	
assign Way1_bank3_addr 	= 	(curstate == IDLE)?index:index_r;
assign Way1_bank3_wdata = 	(curstate == LOOKUP & cache_hit & row_off == 2'b11)?wdata_r://hit store
							(curstate == REFILL)& (row_off == 2'b11)? cache_write_data:0;
	
DATA_bank_ram Way0_bank0(
	.clka(clk), 
	.wea(Way0_bank0_en),//[3:0]
	.addra(Way0_bank0_addr),//[7:0]
	.dina(Way0_bank0_wdata),//[31:0]
	.douta(Way0_bank0_rdata)//[31:0]
);

DATA_bank_ram Way0_bank1(
	.clka(clk), 
	.wea(Way0_bank1_en),//[3:0]
	.addra(Way0_bank1_addr),//[7:0]
	.dina(Way0_bank1_wdata),//[31:0]
	.douta(Way0_bank1_rdata)//[31:0]
);

DATA_bank_ram Way0_bank2(
	.clka(clk), 
	.wea(Way0_bank2_en),//[3:0]
	.addra(Way0_bank2_addr),//[7:0]
	.dina(Way0_bank2_wdata),//[31:0]
	.douta(Way0_bank2_rdata)//[31:0]
);


DATA_bank_ram Way0_bank3(
	.clka(clk), 
	.wea(Way0_bank3_en),//[3:0]
	.addra(Way0_bank3_addr),//[7:0]
	.dina(Way0_bank3_wdata),//[31:0]
	.douta(Way0_bank3_rdata)//[31:0]
);


DATA_bank_ram Way1_bank0(
	.clka(clk), 
	.wea(Way1_bank0_en),//[3:0]
	.addra(Way1_bank0_addr),//[7:0]
	.dina(Way1_bank0_wdata),//[31:0]
	.douta(Way1_bank0_rdata)//[31:0]
);


DATA_bank_ram Way1_bank1(
	.clka(clk), 
	.wea(Way1_bank1_en),//[3:0]
	.addra(Way1_bank1_addr),//[7:0]
	.dina(Way1_bank1_wdata),//[31:0]
	.douta(Way1_bank1_rdata)//[31:0]
);


DATA_bank_ram Way1_bank2(
	.clka(clk), 
	.wea(Way1_bank2_en),//[3:0]
	.addra(Way1_bank2_addr),//[7:0]
	.dina(Way1_bank2_wdata),//[31:0]
	.douta(Way1_bank2_rdata)//[31:0]
);


DATA_bank_ram Way1_bank3(
	.clka(clk), 
	.wea(Way1_bank3_en),//[3:0]
	.addra(Way1_bank3_addr),//[7:0]
	.dina(Way1_bank3_wdata),//[31:0]
	.douta(Way1_bank3_rdata)//[31:0]
);


endmodule

