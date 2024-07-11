`include "defines.v"


module data_ram (
    input wire[`InstAddrBus] addr_i,
    input wire[`RegBus]      data_i,
    input wire               we_i,
    input wire               sel_i,   //字节选择
    input wire               ce_i,    //存储器使能控制

    output reg[`RegBus]     data_o
);
    
endmodule