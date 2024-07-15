`include "defines.v"

module inst_rom (
    input wire               ce,
    input wire[`InstAddrBus] addr,
    output reg[`InstBus]     inst
);
    // 前面是存储单元位宽，注意这个存储单元是多字节的。
    reg[`InstBus] rom[0:`InstMemNum-1];
    initial begin
        $readmemh("C:/Users/Administrator/Desktop/verilog_hdl/Chapter10/rom.data", rom);
    end

    always @(*) begin
        if (ce == `ReadDisable) begin
            inst <= `ZeroWord;
        end else begin
            inst <= rom[addr[`InstMemNumLog2+1:2]];
        end
    end
endmodule