`include "defines.v"
module wb (
    input wire rst,
    input wire[`RegAddrBus] waddr_i,       //目的寄存器地址
    input wire              reg_we_i,      //目的寄存器写使能
    input wire[`RegBus]     data_i,        //写回阶段的指令要写入目的寄存器的值

    output reg[`RegBus]     reg_data_o
);
    
endmodule