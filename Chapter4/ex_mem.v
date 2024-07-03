`include "defines.v"

// EX/MEM 流水线寄存器
module ex_mem (
    input wire rst,
    input wire clk,

    input wire[`RegAddrBus] ex_waddr,       //目标寄存器地址
    input wire              ex_reg_we,      //目标寄存器写使能
    input wire[`RegBus]     ex_alu_res,    //alu运算结果

    output reg[`RegAddrBus] mem_waddr,       //目标寄存器地址
    output reg              mem_reg_we,      //目标寄存器写使能
    output reg[`RegBus]     mem_alu_res      //alu运算结果
);

    
    always @(posedge clk) begin
        // 同步复位
        if (rst == `RstEnable) begin
            mem_waddr <= `NOPRegAddr;
            mem_reg_we <= `WriteDisable;
            mem_alu_res <= `ZeroWord
        end else begin 
            mem_waddr <= ex_waddr;
            mem_reg_we <= ex_reg_we;
            mem_alu_res <= ex_alu_res;

        end
    end
    
endmodule