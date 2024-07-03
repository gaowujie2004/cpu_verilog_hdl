`include "defines.v"

module mem (
    input wire rst,
    input wire[`RegAddrBus] waddr_i,       //目标寄存器地址
    input wire              reg_we_i,      //目标寄存器写使能
    input wire[`RegBus]     alu_res_i      //alu运算结果

    output reg[`RegAddrBus] waddr_o,       //目标寄存器地址
    output reg              reg_we_o,      //目标寄存器写使能
    output reg[`RegBus]     mem_data_o     //内存数据
);

    always @(*) {
        if (rst == `RstEnable) begin
            waddr_o <= `NOPRegAddr;
            reg_we_o <= `WriteDisable;
            mem_data_o <= `ZeroWord;
        end else begin
            waddr_o <= waddr_i;
            reg_we_o <= reg_we_i;
            mem_data_o <= alu_res_i;
        end
    }
    
endmodule