`include "defines.v"

// 寄存器文件：
module regfile (
    input wire rst,
    input wire clk,
    // 写（写回阶段传递的）
    input wire              wb_wreg_i,      //WB阶段，写使能
    input wire[`RegAddrBus] wb_waddr_i,     //WB阶段，目的寄存器地址
    input wire[`RegBus]     wb_wdata_i,     //WB阶段，目的寄存器数据
    // 数据旁路(数据前推)，也相当于写数据
    input wire               mem_wreg_i,    // MEM阶段输出
    input wire[`RegAddrBus]  mem_waddr_i,   // MEM阶段输出
    input wire[`RegBus]      mem_wdata_i,   // MEM阶段输出
    input wire               ex_wreg_i,     // EX阶段输出
    input wire[`RegAddrBus]  ex_waddr_i,    // EX阶段输出
    input wire[`RegBus]      ex_wdata_i,    // EX阶段输出

    //读
    input wire[`RegAddrBus] raddr1,
    input wire              re1,   //端口1读使能
    input wire[`RegAddrBus] raddr2,
    input wire              re2,   //端口2读使能

    //输出（寄存器值）
    output reg[`RegBus]     rdata1,
    output reg[`RegBus]     rdata2
    // Why: rdata1、rdata2 不能是wire，因为在 always 只能对reg变量赋值
);
    reg[`RegBus] regfile[0:`RegNum-1];
    
    // 写
    always @(posedge clk) begin
        if (rst == `RstDisable) begin
            if (wb_wreg_i==`WriteEnable && wb_waddr_i!=`NOPRegAddr) begin
                regfile[wb_waddr_i] <= wb_wdata_i;
            end
        end 
    end

    // 端口1读，读操作不依靠边沿信号
    always @(*) begin
        if (rst == `RstEnable || raddr1 == `NOPRegAddr) begin
            rdata1 <= `ZeroWord;
        end else if (re1 == `ReadEnable) begin
            /*
                Think：数据转发优先级
                ori $1, $0, 11
                ori $1, $0, 22
                ori $1, $0, 33
                ori $3, $1, 44  
                第4条指令读$1，应该是第3条指令的目标寄存器结果，故应该选择最近的数据转发，即选择第3条指令的写数据
            */
            if (ex_wreg_i==`WriteEnable && ex_waddr_i==raddr1) begin
                /*
                    ori $1, $0, 11    写$1
                    ori $1, $0, 22    读$1
                    问题：当第2条指令在ID阶段时，第1条指令在EX阶段
                    解决（数据转发）：将第1条指令的写入$1的数据，作为输出
                */
                rdata1 <= ex_wdata_i;
            end else if (mem_wreg_i==`WriteEnable && mem_waddr_i==raddr1) begin
                /*
                    ori $1, $0, 11    写$1
                    nop
                    ori $1, $0, 22    读$1
                    问题：当第2条指令在ID阶段时，第1条指令在EX阶段
                    解决（数据转发）：将第1条指令的写入$1的数据，作为输出
                */
                rdata1 <= mem_wdata_i;
            end else if (wb_wreg_i == `WriteEnable && wb_waddr_i==raddr1) begin   //WB阶段的信息
                //数据转发：译码读、写回阶段写，，写入的是WB阶段的信息
                //此时读与写端口一致，且都使能，那么就直接将写入信息返回给读，当上升沿一到再写。
                rdata1 <= wb_wdata_i;
            end else begin
                // 不存在数据相关，从regfile读
                rdata1 <= regfile[raddr1];
            end
        end else begin
            rdata1 <= `ZeroWord;
        end
    end

     // 端口2读，读操作不依靠边沿信号
    always @(*) begin
        if (rst == `RstEnable || raddr2 == `NOPRegAddr) begin
            rdata2 <= `ZeroWord;
        end else if (re2 == `ReadEnable) begin
            if (ex_wreg_i==`WriteEnable && ex_waddr_i==raddr2) begin
                rdata2 <= ex_wdata_i;
            end else if (mem_wreg_i==`WriteEnable && mem_waddr_i==raddr2) begin
                rdata2 <= mem_wdata_i;
            end else if (wb_wreg_i == `WriteEnable && wb_waddr_i==raddr2 )begin
                rdata2 <= wb_wdata_i;
            end else begin
                rdata2 <= regfile[raddr2];
            end
        end else begin
            rdata2 <= `ZeroWord;
        end
    end
    
endmodule