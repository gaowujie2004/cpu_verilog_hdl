`include "defines.v"

module openmips_min_sopc (
    input wire rst,
    input wire clk
);
    wire[`InstBus]      rom_inst_o;
    wire                rom_ce_i;
    wire[`InstAddrBus]  rom_addr_i;

    openmips openmips_0(
        .rst(rst), .clk(clk), .rom_data_i(rom_inst_o),
        .rom_ce_o(rom_ce_i), .rom_addr_o(rom_addr_i)    //输出
    );

    inst_rom inst_rom_0(
        .ce(rom_ce_i), .addr(rom_addr_i),
        .inst(rom_inst_o)  //输出
    );
endmodule