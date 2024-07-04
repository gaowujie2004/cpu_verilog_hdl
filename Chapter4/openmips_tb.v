// 顶层模块，CPU的管脚
`include "defines.v"

module openmips_tb (
    input wire rst,
    input wire clk,
    input wire[`InstBus] rom_data_i,      // 指令存储器ROM输入的指令字

    output wire rom_ce_o,                 //ROM读使能
    output wire[`InstAddrBus] rom_addr_o  //输出到ROM的地址
);


endmodule