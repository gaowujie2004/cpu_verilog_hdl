/*
 * 目的：ID阶段结束，下一个时钟上升沿保存ID阶段的结果，立即输出到EX阶段
 * 输入：ID阶段、输出：EX阶段
*/

`include "defines.v"
module id_ex (
    input wire rst,
    input wire clk,
    input wire[`StallBus] stall,

    input wire[`InstBus]    id_inst,        //调试目的
    input wire[`AluSelBus]  id_alusel,
    input wire[`AluOpBus]   id_aluop,
    input wire[`RegBus]     id_reg1_data,   //源操作数1
    input wire[`RegBus]     id_reg2_data,   //源操作数2
    input wire[`RegAddrBus] id_waddr,       //目标寄存器地址
    input wire              id_reg_we,      //目标寄存器写使能

    output reg[`AluSelBus]  ex_alusel,
    output reg[`AluOpBus]   ex_aluop,
    output reg[`RegBus]     ex_reg1_data,   //源操作数1
    output reg[`RegBus]     ex_reg2_data,   //源操作数2
    output reg[`RegAddrBus] ex_waddr,       //目标寄存器地址
    output reg              ex_reg_we,      //目标寄存器写使能
    output reg[`InstBus]    ex_inst         //调试目的
);

    always @(posedge clk) begin
        // 同步复位
        if (rst == `RstEnable) begin
			ex_alusel <= `ALU_RES_NOP;
            ex_aluop <= `ALU_NOP_OP;
			ex_reg1_data <= `ZeroWord;
			ex_reg2_data <= `ZeroWord;
			ex_waddr <= `NOPRegAddr;
			ex_reg_we <= `WriteDisable;
            ex_inst  <= `ZeroWord;
        end else begin
            if (stall[2]==`Stop && stall[3]==`NotStop) begin
                ex_alusel <= `ALU_RES_NOP;
                ex_aluop  <= `ALU_NOP_OP;
                ex_reg1_data <= `ZeroWord;
                ex_reg2_data <= `ZeroWord;
                ex_waddr  <= `NOPRegAddr;
                ex_reg_we <= `WriteDisable;
                ex_inst   <= id_inst;                
            end else if(stall[2] == `NotStop) begin
                ex_alusel <= id_alusel;
                ex_aluop <= id_aluop;
                ex_reg1_data <= id_reg1_data;
                ex_reg2_data <= id_reg2_data;
                ex_waddr <= id_waddr;
                ex_reg_we <= id_reg_we;	
                ex_inst  <= id_inst;                
            end else begin
                // not change
            end
        end
    end
    
endmodule

