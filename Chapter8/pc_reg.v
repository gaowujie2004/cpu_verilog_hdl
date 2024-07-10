`include "defines.v"

module pc_reg (
    input wire rst,
    input wire clk,
    input wire[`StallBus] stall,
    input wire[`InstAddrBus] branch_target_address_i,   //跳转目的地址
    input wire               branch_flag_i,             //是否跳转

    output reg[`InstAddrBus] pc,
    output reg ce
);

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            ce <= `ChipDisable;
        end else begin
            ce <= `ChipEnable;
        end
    end
    
    always @(posedge clk) begin 
        if (ce == `ChipEnable) begin
            if (stall[0] == `NotStop) begin
                pc <= pc + 4'h4;
            end
        end else begin 
            pc <= `ZeroWord;
        end
    end

endmodule