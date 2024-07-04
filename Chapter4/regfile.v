`include "defines.v"

// 寄存器文件：
module regfile (
    input wire rst,
    input wire clk,
    // 写
    input wire[`RegAddrBus] waddr,
    input wire[`RegBus]     wdata,
    input wire              we,    //写使能

    //读
    input wire[`RegAddrBus] raddr1,
    input wire[`RegBus]     re1,   //端口1读使能
    input wire[`RegAddrBus] raddr2,
    input wire[`RegBus]     re2,   //端口2读使能

    //输出（寄存器值）
    output reg[`RegBus]     rdata1,
    output reg[`RegBus]     rdata2

    // Why: 我理解这里可以改成 wire 类型了。？
);

    // Why: 注意，这里0:RegNum-1，为什么啊？后面声明的是个数。
    reg[`RegBus] regfile[0:`RegNum-1];
    
    // 写
    always @(posedge clk) begin
        if (rst == `RstDisable) begin
            if (we == `WriteEnable && waddr != `NOPRegAddr) begin
                regfile[waddr] <= wdata;
            end
        end 
    end

    // 端口1读，读操作不依靠边沿信号
    always @(*) begin
        if (rst == `RstEnable || raddr1 == `NOPRegAddr) begin
            rdata1 <= `ZeroWord;
        end else if (raddr1 == waddr && re1 == `ReadEnable && we == `WriteEnable) begin 
            // 读与写端口一致，且都使能，那么就直接将写入信息返回给读，当上升沿一到再写。
            rdata1 <= wdata;
        end else if (re1 == `ReadEnable) begin 
            rdata1 <= regfile[raddr1];
        end else begin
            rdata1 <= `ZeroWord;
        end
    end

     // 端口2读，读操作不依靠边沿信号
    always @(*) begin
        if (rst == `RstEnable || raddr2 == `NOPRegAddr) begin
            rdata2 <= `ZeroWord;
        end else if (raddr2 == waddr && re2 == `ReadEnable && we == `WriteEnable) begin 
            // 读与写端口一致，且都使能，那么就直接将写入信息返回给读，当上升沿一到再写。
            rdata2 <= wdata;
        end else if (re2 == `ReadEnable) begin 
            rdata2 <= regfile[raddr2];
        end else begin
            rdata2 <= `ZeroWord;
        end
    end
    
endmodule