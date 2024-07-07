`include "defines.v"

// EX/MEM 流水线寄存器
module ex_mem (
    input wire rst,
    input wire clk,
    input wire[`InstBus]    ex_inst,      //debuger

    input wire[`RegAddrBus] ex_waddr,     //目标寄存器地址
    input wire              ex_reg_we,    //目标寄存器写使能
    input wire[`RegBus]     ex_alu_res,   //alu运算结果

    input wire             ex_hi_we,       //Hi寄存器写使能
    input wire             ex_lo_we,       //Lo寄存器写使能
    input wire[`RegBus]    ex_hi,          //指令执行阶段对Hi写入的数据
    input wire[`RegBus]    ex_lo,          //指令执行阶段对Lo写入的数据


    output reg[`RegAddrBus] mem_waddr,       
    output reg              mem_reg_we,      
    output reg[`RegBus]     mem_alu_res,

    output reg              mem_hi_we,       
    output reg              mem_lo_we,       
    output reg[`RegBus]     mem_hi,          
    output reg[`RegBus]     mem_lo,

    output reg[`InstBus]   mem_inst        //debuger
);

    
    always @(posedge clk) begin
        // 同步复位
        if (rst == `RstEnable) begin
            mem_waddr <= `NOPRegAddr;
            mem_reg_we <= `WriteDisable;
            mem_alu_res <= `ZeroWord;
            mem_hi_we   <= `WriteDisable;
            mem_lo_we   <= `WriteDisable;
            mem_hi      <= `ZeroWord;
            mem_lo      <= `ZeroWord;
            mem_inst      <= `ZeroWord;
        end else begin 
            mem_waddr <= ex_waddr;
            mem_reg_we <= ex_reg_we;
            mem_alu_res <= ex_alu_res;
            mem_hi_we   <= ex_hi_we;
            mem_lo_we   <= ex_lo_we;
            mem_hi      <= ex_hi;
            mem_lo      <= ex_lo;
            mem_inst    <= ex_inst;
        end
    end
    
endmodule