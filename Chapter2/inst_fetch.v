module inst_fetch (
    input wire rst,
    input wire clk,
    output wire[31:0] inst_o
);

    // 内部的信号线，用于连接PC模块的输出和ROM模块的输入
    wire[5:0] pc;
    wire rom_ce;

    // pc_reg 模块元件例化
    pc_reg pc_reg_0(
        .clk(clk),
        .rst(rst),              // .rst 是 pc_reg 模块的输出端口名，inst_fetch 的输入信号 rst 连接到 .rst 上
        .pc(pc),
        .ce(rom_ce)             // .ce 是 pc_reg 模块的端口名，它的输出连接到 rom_ce 这根信号线上。
    );

    // rom 模块元件例化
    inst_rom inst_rom0(
        .ce(rom_ce),
        .addr(pc),
        .inst(inst_o)
    );

endmodule