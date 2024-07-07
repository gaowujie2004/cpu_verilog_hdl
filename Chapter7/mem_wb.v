// MEM/WB 流水线寄存器

`include "defines.v"
module mem_wb (
    input wire rst,
    input wire clk,

    input wire[`RegAddrBus] mem_waddr,
    input wire              mem_reg_we,
    input wire[`RegBus]     mem_data,

    input wire             mem_hi_we,       //Hi寄存器写使能
    input wire             mem_lo_we,       //Lo寄存器写使能
    input wire[`RegBus]    mem_hi,          //指令执行阶段对Hi写入的数据
    input wire[`RegBus]    mem_lo,          //指令执行阶段对Lo写入的数据



    output reg[`RegAddrBus] wb_waddr,
    output reg              wb_reg_we,
    output reg[`RegBus]     wb_data,        //写回阶段的指令要写入目的寄存器的值

    output reg              wb_hi_we,       
    output reg              wb_lo_we,       
    output reg[`RegBus]     wb_hi,          
    output reg[`RegBus]     wb_lo
);
    always @(posedge clk) begin
        // 同步复位
        if (rst == `RstEnable) begin
            wb_waddr  <= `NOPRegAddr;
            wb_reg_we <= `WriteDisable;
            wb_data   <= `ZeroWord;

            wb_hi_we   <= `WriteDisable;
            wb_lo_we   <= `WriteDisable;
            wb_hi      <= `ZeroWord;
            wb_lo      <= `ZeroWord;
        end else begin
            wb_waddr  <= mem_waddr;
            wb_reg_we <= mem_reg_we;
            wb_data   <= mem_data; 

            wb_hi_we   <= mem_hi_we;
            wb_lo_we   <= mem_lo_we;
            wb_hi      <= mem_hi;
            wb_lo      <= mem_lo;
        end
    end
endmodule
