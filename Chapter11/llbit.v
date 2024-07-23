`include "defines.v"

module llbit (
    input wire clk,
    input wire rst,
    input wire flush,           //异常是否发⽣，为1表示异常发⽣，为0表示没有异常
    input wire wb_we_i,
    input wire wb_llbit_i,
    
    output reg llbit_o
);
    reg llbit;
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            llbit <= 1'b0;
        end else if (flush == 1'b1) begin //异常发生，清零
            llbit <= 1'b0;
        end else if (wb_we_i == `WriteEnable) begin
            llbit <= wb_llbit_i;
        end
    end
    
    always @(*) begin
        /*
            WB Stage：write llbit
            MEM Stage: read llbit
            问题：一条指令在MEM阶段，那么前面指令的write llbit就在WB阶段，但要等到下一个时钟周期上升沿才能写入到llbit寄存器。
            解决：数据转发(数据前推)，和Regfile、HiLo模块一样的思路。
                  我们设计的是在MEM Stage读llbit，在WB Stage写llbit，故而MEM之前的阶段都不需要考虑数据转发(数据前推)
        */
        if (flush == 1'b1) begin
            llbit_o = 1'b0;
        end else if (wb_we_i == `WriteEnable) begin
            llbit_o = wb_llbit_i;
        end else begin
            llbit_o = llbit;
        end
    end
endmodule