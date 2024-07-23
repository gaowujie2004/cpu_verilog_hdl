/*
 * 目的：IF阶段结束，下一个时钟上升沿保存到IF阶段的结果，并立即输出到ID阶段。
*/

`include "defines.v"
module if_id (
    input wire rst,
    input wire clk,
    input wire[`StallBus] stall,
    input wire            flush,        //响应中断，清零

    input wire[`InstAddrBus] if_pc,
    input wire[`InstBus]     if_inst,

    output reg[`InstAddrBus] id_pc,
    output reg[`InstBus]     id_inst
);

    always @(posedge clk ) begin
        // 同步复位
        if (rst == `RstEnable) begin
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;   //NOP空指令
        end else begin 
            if (flush == `True_v) begin
                id_pc <= `ZeroWord;
                id_inst <= `ZeroWord;   //NOP空指令
            end else if (stall[1]==`Stop && stall[2]==`NotStop) begin
                id_pc   <= `ZeroWord;
                id_inst <= `ZeroWord;
            end else if (stall[1]==`NotStop) begin
                id_pc <= if_pc;
                id_inst <= if_inst;                
            end else begin
                // 保持不变
            end
        end
    end
    
endmodule

