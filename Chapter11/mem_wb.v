// MEM/WB 流水线寄存器

`include "defines.v"
module mem_wb (
    input wire rst,
    input wire clk,
    input wire[`StallBus] stall,
    input wire[`InstBus]    mem_inst,       //debuger

    input wire[`RegAddrBus] mem_waddr,
    input wire              mem_reg_we,
    input wire[`RegBus]     mem_wdata,

    input wire             mem_hi_we,       //Hi寄存器写使能
    input wire             mem_lo_we,       //Lo寄存器写使能
    input wire[`RegBus]    mem_hi,          //指令执行阶段对Hi写入的数据
    input wire[`RegBus]    mem_lo,          //指令执行阶段对Lo写入的数据

    input wire             mem_llbit_we,    //访存阶段的指令是否要写LLbit寄存器
    input wire             mem_llbit_value, //访存阶段的指令写入LLbit的数据

    /*cp0 mt(f)c0*/
    input wire             mem_cp0_we,     //写使能
    input wire[4:0]        mem_cp0_waddr,  //写CP0寄存器的地址
    input wire[`RegBus]    mem_cp0_wdata,  //写入CP0寄存器的数据

    output reg[`RegAddrBus] wb_waddr,
    output reg              wb_reg_we,
    output reg[`RegBus]     wb_wdata,       //写回阶段的指令要写入目的寄存器的值

    output reg              wb_hi_we,       
    output reg              wb_lo_we,       
    output reg[`RegBus]     wb_hi,          
    output reg[`RegBus]     wb_lo,

    output reg              wb_llbit_we,    
    output reg              wb_llbit_value, 

    /*cp0 mt(f)c0*/
    output reg              wb_cp0_we,      //写使能
    output reg[4:0]         wb_cp0_waddr,   //写CP0寄存器的地址
    output reg[`RegBus]     wb_cp0_wdata,   //写入CP0寄存器的数据

    output reg[`InstBus]    wb_inst        //debuger
);
    always @(posedge clk) begin
        // 同步复位
        if (rst == `RstEnable) begin
            wb_waddr  <= `NOPRegAddr;
            wb_reg_we <= `WriteDisable;
            wb_wdata  <= `ZeroWord;

            wb_hi_we   <= `WriteDisable;
            wb_lo_we   <= `WriteDisable;
            wb_hi      <= `ZeroWord;
            wb_lo      <= `ZeroWord;

            wb_llbit_we    <= `WriteDisable;
            wb_llbit_value <= 1'b0;

            wb_cp0_we     <= `WriteDisable;
            wb_cp0_waddr  <= `ZeroWord;
            wb_cp0_wdata  <= `ZeroWord;

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
                wb_wdata   <= `ZeroWord;

                wb_hi_we   <= `WriteDisable;
                wb_lo_we   <= `WriteDisable;
                wb_hi      <= `ZeroWord;
                wb_lo      <= `ZeroWord;

                wb_llbit_we    <= `WriteDisable;
                wb_llbit_value <= 1'b0;

                wb_cp0_we     <= `WriteDisable;
                wb_cp0_waddr  <= `ZeroWord;
                wb_cp0_wdata  <= `ZeroWord;

                wb_inst    <= mem_inst;         //debuger        
            end else if (stall[4] == `NotStop) begin
                /*
                 * MEM阶段继续，那其他情况就不用考虑了，直接继续执行进入下个阶段
                */   
                wb_waddr  <= mem_waddr;
                wb_reg_we <= mem_reg_we;
                wb_wdata  <= mem_wdata; 

                wb_hi_we   <= mem_hi_we;
                wb_lo_we   <= mem_lo_we;
                wb_hi      <= mem_hi;
                wb_lo      <= mem_lo;

                wb_llbit_we    <= mem_llbit_we;
                wb_llbit_value <= mem_llbit_value;

                wb_cp0_we     <= mem_cp0_we;
                wb_cp0_waddr  <= mem_cp0_waddr;
                wb_cp0_wdata  <= mem_cp0_wdata;

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
