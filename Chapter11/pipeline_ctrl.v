`include "defines.v"



/*
 * 生成流水线暂停控制信号、清零信号，控制流水线运行
*/
module pipeline_ctrl (
    input wire rst,
    input wire stallreq_from_id,
    input wire stallreq_from_ex,

    output reg[`StallBus] stall
);
    always @(*) begin
        if (rst == `RstEnable) begin
            stall <= 6'b000000;
        end else if (stallreq_from_ex == `Stop) begin
            // Why: 为什么先判断ex阶段，而不是id阶段？或者说此次的顺序调换会影响预期吗？
            // 若ex、id都暂停，必须先判断ex，因为ex写入stall=6'b001111，而id写入stall=6'b000111，明显ex包含id
            stall <= 6'b001111; //数值的右边是低位。
        end else if (stallreq_from_id == `Stop) begin
            stall <= 6'b000111;
        end else begin
            stall <= 6'b000000;
        end
    end
endmodule