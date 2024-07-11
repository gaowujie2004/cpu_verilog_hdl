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
    input wire[`RegBus]     id_op1_data,   //源操作数1
    input wire[`RegBus]     id_op2_data,   //源操作数2
    input wire[`RegAddrBus] id_waddr,       //目标寄存器地址
    input wire              id_reg_we,      //目标寄存器写使能
    input wire              id_is_in_delayslot, //ID阶段的指令是否是延迟槽指令
    input wire[`InstAddrBus] id_link_address,    //返回地址，写入目的寄存器
    input wire              id_next_inst_in_delayslot, //IF阶段的指令是否是延迟槽指令

    output reg[`AluSelBus]  ex_alusel,
    output reg[`AluOpBus]   ex_aluop,
    output reg[`RegBus]     ex_op1_data,   //源操作数1
    output reg[`RegBus]     ex_op2_data,   //源操作数2
    output reg[`RegAddrBus] ex_waddr,       //目标寄存器地址
    output reg              ex_reg_we,      //目标寄存器写使能
    output reg[`InstBus]    ex_inst,        //调试目的
    output reg              ex_is_indelayslot, //ID阶段的指令是否是延迟槽指令
    output reg[`InstAddrBus]ex_link_address,   //返回地址，写入目的寄存器
    output reg              is_in_delayslot    //id_next_inst_in_delayslot作为输出
);

    always @(posedge clk) begin
        // 同步复位
        if (rst == `RstEnable) begin
			ex_alusel <= `ALU_RES_NOP;
            ex_aluop <= `ALU_NOP_OP;
			ex_op1_data <= `ZeroWord;
			ex_op2_data <= `ZeroWord;
			ex_waddr  <= `NOPRegAddr;
			ex_reg_we <= `WriteDisable;
            ex_inst   <= `ZeroWord;
            ex_is_indelayslot  <= `False_v;
            ex_link_address    <= `ZeroWord;
            is_in_delayslot    <= `False_v;
        end else begin
            if (stall[2]==`Stop && stall[3]==`NotStop) begin
                //气泡
                ex_alusel <= `ALU_RES_NOP;
                ex_aluop  <= `ALU_NOP_OP;
                ex_op1_data <= `ZeroWord;
                ex_op2_data <= `ZeroWord;
                ex_waddr  <= `NOPRegAddr;
                ex_reg_we <= `WriteDisable;
                ex_inst   <= id_inst;
                ex_is_indelayslot  <= `False_v;
                ex_link_address    <= `ZeroWord;    
                // Why: 为什么呢？is_in_delayslot  not change
            end else if(stall[2] == `NotStop) begin
                //无暂停
                ex_alusel <= id_alusel;
                ex_aluop  <= id_aluop;
                ex_op1_data <= id_op1_data;
                ex_op2_data <= id_op2_data;
                ex_waddr  <= id_waddr;
                ex_reg_we <= id_reg_we;	
                ex_inst   <= id_inst;    
                ex_is_indelayslot  <= id_is_in_delayslot;
                ex_link_address    <= id_link_address;   
                is_in_delayslot    <= id_next_inst_in_delayslot;
            end else begin
                // not change
                // 暂停
            end
        end
    end
    
endmodule

