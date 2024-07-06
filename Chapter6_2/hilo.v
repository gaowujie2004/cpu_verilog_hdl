module hilo (
    wire rst,
    input wire clk,
    input wire hi_we_i,
    input wire lo_we_i,
    input wire[`RegBus] hi_i,           //写入hi寄存器的数据
    input wire[`RegBus] lo_i,           //写入lo寄存器的数据

    output reg[`RegBus] hi_o,           //读出hi寄存器的数据
    output reg[`RegBus] lo_o            //读出lo寄存器的数据
);

    

    always @(posedge clk) begin
        if (rst == `RstEnable) begin 
            hi_o <= `ZeroWord; 
            lo_o <= `ZeroWord; 
        end else begin 
            if (hi_we_i == `WriteEnable) begin
                hi_o <= hi_i; 
            end 
            
            if (lo_we_i == `WriteEnable) begin
                lo_o <= lo_i;
            end
        end
    end
endmodule