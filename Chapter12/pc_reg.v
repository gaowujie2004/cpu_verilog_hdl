`include "defines.v"

module pc_reg (
    input wire rst,
    input wire clk,
    input wire[`StallBus] stall,
    input wire[`InstAddrBus] branch_target_address_i,   //跳转目的地址
    input wire               branch_flag_i,             //是否跳转
    input wire               flush,                     //响应异常
    input wire[`InstAddrBus] exception_handle_addr_i,   //异常处理程序的入口地址

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
            // Why：为什么想这样的？难道flush真时，stall会起作用？因为它优先级高？只要flush了就说明要响应中断了。
            if (flush == `True_v) begin
                pc <= exception_handle_addr_i;
            end else if (stall[0] == `NotStop) begin
                if (branch_flag_i == `Branch) begin
                    pc <= branch_target_address_i;
                end  else begin
                    pc <= pc + 4'h4;
                end
            end else begin
                // stall. pc not change
            end
        end else begin 
            pc <= `ZeroWord;
        end
    end

endmodule