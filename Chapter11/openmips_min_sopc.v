`include "defines.v"

module openmips_min_sopc (
    input wire rst,
    input wire clk
);
    wire[`InstBus]      rom_inst_o;
    wire                rom_ce_i;
    wire[`InstAddrBus]  rom_addr_i;

    wire[`InstAddrBus] ram_addr;
    wire               ram_we;
    wire               ram_ce; 
    wire[`MemSelBus]   ram_sel;
    wire[`RegBus]      ram_wdata;
    wire[`RegBus]      ram_data_o;

    wire[5:0]          timer_int_o;  

    openmips openmips_0(
        .rst(rst), .clk(clk), .rom_data_i(rom_inst_o), .ram_data_i(ram_data_o),
        .int_i({5'b00000, timer_int_o}),

        /*rom*/
        .rom_ce_o(rom_ce_i), .rom_addr_o(rom_addr_i),
        /*ram*/
        .ram_addr_o(ram_addr), 
        .ram_we_o(ram_we),
        .ram_ce_o(ram_ce),  
        .ram_sel_o(ram_sel),
        .ram_wdata_o(ram_wdata),
        /*int*/
        .timer_int_o(timer_int_o)   //时钟中断输出
    );

    inst_rom inst_rom_0(
        .ce(rom_ce_i), .addr(rom_addr_i),

        .inst(rom_inst_o)
    );

    data_ram data_ram_0(
    	.clk    (clk    ),
        .addr_i (ram_addr),
        .data_i (ram_wdata),
        .we_i   (ram_we   ),
        .sel_i  (ram_sel  ),
        .ce_i   (ram_ce   ),

        .data_o (ram_data_o)
    );
    
endmodule