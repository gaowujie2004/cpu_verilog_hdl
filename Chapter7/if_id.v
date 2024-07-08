/*
 * 目的：IF阶段结束，下一个时钟上升沿保存到IF阶段的结果，并立即输出到ID阶段。
*/

`include "defines.v"
module if_id (
    input wire rst,
    input wire clk,
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
            id_pc <= if_pc;
            id_inst <= if_inst;
        end
    end
    
endmodule

