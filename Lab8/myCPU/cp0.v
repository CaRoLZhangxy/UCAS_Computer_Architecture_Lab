`include "mycpu.h"

module cp0(
    input                   clk             ,
    input                   reset           ,

    input                   mtc0_we         ,
    input  [ 7: 0]          c0_addr         ,
    input  [31: 0]          c0_wdata        ,
    input                   wb_ex           ,
    input                   eret_flush      ,
    input                   wb_bd           ,
    input  [ 5: 0]          ext_int_in      ,
    input  [ 4: 0]          wb_excode       ,
    input  [31: 0]          wb_pc           ,
    

    output [31: 0]          c0_status       ,
    output [31: 0]          c0_cause        ,
    output [31: 0]          c0_epc          ,
    output [31: 0]          c0_count        ,
    output [31: 0]          c0_compare      
);
    wire                    count_eq_compare;
    wire                    c0_status_bev   ;
    reg     [ 7: 0]         c0_status_im    ;
    reg                     c0_status_exl   ;
    reg                     c0_status_ie    ;
    reg                     c0_cause_bd     ;
    reg                     c0_cause_ti     ;
    reg     [ 7: 0]         c0_cause_ip     ;
    reg     [ 4: 0]         c0_cause_excode ;
    reg     [31: 0]         c0_epc_r        ;
    reg                     tick            ;
    reg     [31: 0]         c0_count_r      ;
    reg     [31: 0]         c0_compare_r    ;

    
    assign c0_status_bev = 1'b1;

    
    always @(posedge clk)
    begin
        if (mtc0_we && c0_addr == `CR_STATUS)
            c0_status_im <= c0_wdata[15:8];
    end

    
    always @(posedge clk) 
    begin
        if(reset)
            c0_status_exl <= 1'b0;
        else if (wb_ex)
            c0_status_exl <= 1'b1;
        else if (eret_flush)
            c0_status_exl <= 1'b0;
        else if (mtc0_we && c0_addr == `CR_STATUS)
            c0_status_exl <= c0_wdata[1];
    end

    
    always @(posedge clk)
    begin
        if(reset)
            c0_status_ie <= 1'b0;
        else if (mtc0_we && c0_addr == `CR_STATUS)
            c0_status_ie <= c0_wdata[0];
    end

    assign c0_status = {9'b0             ,     // 31:23      
                        c0_status_bev    ,     // 22
                        6'b0             ,     // 21:16
                        c0_status_im     ,     // 15:8
                        6'b0             ,     // 7: 2
                        c0_status_exl    ,     // 1
                        c0_status_ie           // 0
                        };
    
    
    always @(posedge clk)
    begin
        if(reset)
            c0_cause_bd <= 1'b0;
        else if (wb_ex && !c0_status_exl)
            c0_cause_bd <= wb_bd;
    end

    
    always @(posedge clk)
    begin
        if (reset)
            c0_cause_ti <= 1'b0;
        else if (mtc0_we && c0_addr == `CR_COMPARE)
            c0_cause_ti <= 1'b0;
        else if (count_eq_compare)
            c0_cause_ti <= 1'b1;
    end
    
    always @(posedge clk)
    begin
        if(reset)
            c0_cause_ip[7:2] <= 6'b0;
        else 
        begin
            c0_cause_ip[7]   <= ext_int_in[5] | c0_cause_ti;
            c0_cause_ip[6:2] <= ext_int_in[4:0];
        end
    end
    always @(posedge clk)
    begin
        if(reset)
            c0_cause_ip[1:0] <= 2'b0;
        else if (mtc0_we && c0_addr == `CR_CAUSE)
            c0_cause_ip[1:0] <= c0_wdata[9:8];
    end
    
    always @(posedge clk)
    begin
        if(reset)
            c0_cause_excode <= 5'b0;
        else if (wb_ex)
            c0_cause_excode <= wb_excode;
    end

    assign c0_cause      = {c0_cause_bd            , // 31
                            c0_cause_ti            , // 30
                            14'b0                  , // 29:16
                            c0_cause_ip            , // 15: 8
                            1'b0                   , // 7
                            c0_cause_excode        , // 6: 2
                            2'b0
                            };

    
    always @(posedge clk)
    begin
        if(wb_ex && !c0_status_exl)
            c0_epc_r <= wb_bd ? wb_pc - 3'h4 : wb_pc ; 
        else if (mtc0_we && c0_addr == `CR_EPC)
            c0_epc_r <= c0_wdata;
    end
    assign c0_epc = c0_epc_r;
    
    always @(posedge clk)
    begin
        if (reset) tick <= 1'b0;
        else tick <= ~tick;

        if (mtc0_we && c0_addr == `CR_COUNT)
            c0_count_r <= c0_wdata;
        else if (tick)
            c0_count_r <= c0_count_r +1'b1;
    end
    assign c0_count = c0_count_r;

    
    always@(posedge clk) 
    begin
    if(reset) 
        c0_compare_r <= 32'b0;
    else if(mtc0_we && c0_addr == `CR_COMPARE) 
        c0_compare_r <= c0_wdata;
    end
    assign c0_compare = c0_compare_r;
    //assign count_eq_compare = (c0_compare == c0_count);
    assign count_eq_compare = 1'b0;
endmodule
