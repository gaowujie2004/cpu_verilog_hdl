`include "defines.v"
/*
 * EX/MEM流水寄存器
 * 目的：EX阶段结束，下一个时钟上升沿保存EX阶段的结果，立即输出到MEM阶段
 * 输入：EX阶段、输出：MEM阶段
*/
module ex_mem (
    input wire rst,
    input wire clk,
    input wire[`StallBus] stall,
    
    input wire[`InstBus]    ex_inst,      //debuger

    input wire[`RegAddrBus] ex_waddr,     //目标寄存器地址
    input wire              ex_reg_we,    //目标寄存器写使能
    input wire[`RegBus]     ex_alu_res,   //alu运算结果

    input wire             ex_hi_we,       //Hi寄存器写使能
    input wire             ex_lo_we,       //Lo寄存器写使能
    input wire[`RegBus]    ex_hi,          //指令执行阶段对Hi写入的数据
    input wire[`RegBus]    ex_lo,          //指令执行阶段对Lo写入的数据

    input wire[1:0]         ex_cnt,         //madd(u)、msub(u)使用，第几个周期
    input wire[`DoubleRegBus] ex_hilo_temp, //madd(u)、msub(u)使用，相乘的中间结果

    output reg[`RegAddrBus] mem_waddr,       
    output reg              mem_reg_we,      
    output reg[`RegBus]     mem_alu_res,

    output reg              mem_hi_we,       
    output reg              mem_lo_we,       
    output reg[`RegBus]     mem_hi,          
    output reg[`RegBus]     mem_lo,

    output reg[1:0]         cnt_o,         
    output reg[`DoubleRegBus] hilo_temp_o,

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
            mem_inst    <= `ZeroWord;
            cnt_o       <= 2'b00;
            hilo_temp_o <= {`ZeroWord, `ZeroWord};
        end else begin
            if (stall[3]==`Stop && stall[4]==`NotStop) begin
                /*
                 * EX阶段暂停，⽽MEM阶段继续，所以使⽤NOP作为下⼀个周期进⼊MEM阶段的指令
                 * EX阶段结束，下一个周期一到：
                 *   1.原本的MEM阶段的指令进入WB阶段
                 *   2.MEM阶段是NOP指令
                */
                mem_waddr   <= `NOPRegAddr;
                mem_reg_we  <= `WriteDisable;
                mem_alu_res <= `ZeroWord;
                mem_hi_we   <= `WriteDisable;
                mem_lo_we   <= `WriteDisable;
                mem_hi      <= `ZeroWord;
                mem_lo      <= `ZeroWord;
                mem_inst    <= ex_inst;         //debuger
                /*
                 * madd(u)、msub(u)符合这个if条件
                */
                cnt_o       <= ex_cnt;
                hilo_temp_o <= ex_hilo_temp;
            end else if (stall[3] == `NotStop) begin
                /*
                 * MEM阶段继续，那其他情况就不用考虑了，直接继续执行进入下个阶段
                */                
                mem_waddr   <= ex_waddr;
                mem_reg_we  <= ex_reg_we;
                mem_alu_res <= ex_alu_res;
                mem_hi_we   <= ex_hi_we;
                mem_lo_we   <= ex_lo_we;
                mem_hi      <= ex_hi;
                mem_lo      <= ex_lo;
                mem_inst    <= ex_inst;   
                cnt_o       <= 2'b00;
                hilo_temp_o <= {`ZeroWord, `ZeroWord};             
            end else begin
                /*
                 * 其余情况，保持流水线寄存器的值
                */
                /* Why: 只要EX被暂停，即EX/MEM.STOP=1，那就传递cnt、hilo_temp信号 */
                cnt_o       <= ex_cnt;
                hilo_temp_o <= ex_hilo_temp;
            end
        end
    end
    
endmodule