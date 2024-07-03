`include "defines.v"

module pc_reg (
    input wire rst,
    input wire clk,
    output reg[`InstAddrBus] pc,
    output reg ce
);

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            ce <= ChipDisable;
        end else begin
            ce <= ChipEnable;
        end
    end
    
    always @(posedge clk) begin 
        if (ce == `ChipEnable) begin 
            pc <= pc + 4'h4;
        end else begin 
            pc <= `InstAddrBus'b0;
        end
    end

endmodule