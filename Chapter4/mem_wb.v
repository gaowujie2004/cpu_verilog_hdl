// MEM/WB 流水线寄存器

`include "defines.v"
module mem_wb (
    input wire rst,
    input wire clk,

    input wire[`RegAddrBus] mem_waddr,
    input wire              mem_reg_we,
    input wire[`RegBus]     mem_data,

    output reg[`RegAddrBus] wb_waddr,
    output reg              wb_reg_we,
    output reg[`RegBus]     wb_data,        //写回阶段的指令要写入目的寄存器的值
);
    always @(posedge clk) begin
        // 同步复位
        if (rst == `RstEnable) begin
            wb_waddr  <= `NOPRegAddr;
            wb_reg_we <= `WriteDisable;
            wb_data   <= `ZeroWord; 
        end else begin
            wb_waddr  <= mem_waddr;
            wb_reg_we <= mem_reg_we;
            wb_data   <= mem_data; 
        end
    end
endmodule
