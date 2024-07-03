`include "defines.v"
module if_id2 (
    input wire rst,
    input wire clk,
    input wire[`InstAddrBus] if_pc,
    input wire[`InstBus]     if_inst,

    output wire[`InstAddrBus] id_pc,
    output wire[`InstBus]     id_inst
);
    reg[`InstAddrBus] inner_addr;
    reg[`InstBus]     inner_inst;

    always @(posedge clk ) begin
        // 同步复位
        if (rst == `RstEnable) begin
            inner_addr <= `InstAddrBus'b0;
            inner_inst <= `InstBus'b0;
        end else begin 
            inner_addr <= if_pc;
            inner_inst <= if_inst;
        end
    end

    always @(posedge clk ) begin
        id_pc <= inner_addr;
        id_inst <= inner_inst
    end
    
endmodule