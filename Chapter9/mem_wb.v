// MEM/WB 流水线寄存器

`include "defines.v"
module mem_wb (
    input wire rst,
    input wire clk,
    input wire[`StallBus] stall,
    input wire[`InstBus]    mem_inst,       //debuger

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
    output reg[`RegBus]     wb_lo,

    output reg[`InstBus]    wb_inst        //debuger
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

            wb_inst    <= `ZeroWord;
        end else begin
            if (stall[4]==`Stop && stall[5]==`NotStop) begin
                /*
                 * MEM阶段暂停，⽽WB阶段继续，所以使⽤NOP作为下⼀个周期进⼊WB阶段的指令
                 * MEM阶段结束，下一个周期一到：
                 *   1.原本的WB阶段处理结果，写回寄存器完成
                 *   2.而WB阶段则是NOP指令
                */
                wb_waddr   <= `NOPRegAddr;
                wb_reg_we  <= `WriteDisable;
                wb_data    <= `ZeroWord;

                wb_hi_we   <= `WriteDisable;
                wb_lo_we   <= `WriteDisable;
                wb_hi      <= `ZeroWord;
                wb_lo      <= `ZeroWord;

                wb_inst    <= mem_inst;         //debuger        
            end else if (stall[4] == `NotStop) begin
                /*
                 * MEM阶段继续，那其他情况就不用考虑了，直接继续执行进入下个阶段
                */   
                wb_waddr  <= mem_waddr;
                wb_reg_we <= mem_reg_we;
                wb_data   <= mem_data; 

                wb_hi_we   <= mem_hi_we;
                wb_lo_we   <= mem_lo_we;
                wb_hi      <= mem_hi;
                wb_lo      <= mem_lo;

                wb_inst    <= mem_inst;                
            end else begin
                /*
                 * 只考虑与MEM、WB相关的阶段，其他阶段不考虑，
                 * 故如果是其他情况，那就流水寄存器不变。
                */
            end

        end
    end
endmodule
