`include "defines.v"


/*
 * 生成流水线暂停控制信号、清零信号，控制流水线运行
*/
module pipeline_ctrl (
    input wire rst,
    input wire stallreq_from_id,
    input wire stallreq_from_ex,
    input wire[`ExceptionTypeBus] exception_i,
    input wire[`RegBus]           cp0_epc_i,

    output reg[`StallBus] stall,    //数值的右边是低位，低位从PC_reg依次向后、IF/EX、EX/MEM ....。
    output reg            flush,    //响应中断，清空寄存器，让其变成NOP指令
    output reg[`InstAddrBus] exec_handler_addr  //异常处理程序的地址   
);
    always @(*) begin
        if (rst == `RstEnable) begin
            stall <= 6'b000000;
            flush <= `False_v;
            exec_handler_addr <= `ZeroWord;
        end else begin
            stall <= 6'b000000;
            flush <= `False_v;
            exec_handler_addr <= `ZeroWord;

            /*
            * 异常的优先级比流水线暂停高
            */
            if (exception_i != `ZeroWord) begin //发生异常
                flush <= `True_v;
                case (exception_i)
                    `Exc_Interrupt: begin
                        exec_handler_addr <= 32'h00000020;
                    end
                    `Exc_Syscall, `Exc_InvalidInst, `Exc_Trap, `Exc_Overflow: begin
                        exec_handler_addr <= 32'h00000040;
                    end
                    `Exc_Eret: begin
                        exec_handler_addr <= cp0_epc_i;
                    end
                endcase
            end else if (stallreq_from_ex == `Stop) begin
                /*
                * Why: 为什么先判断ex阶段，而不是id阶段？或者说此次的顺序调换会影响预期吗？
                * Because：若ex、id都暂停，必须先判断ex，因为ex写入stall=6'b001111，而id写入stall=6'b000111，明显ex包含id
                */
                stall <= 6'b001111;
            end else if (stallreq_from_id == `Stop) begin
                stall <= 6'b000111;
            end
        end
    end
endmodule