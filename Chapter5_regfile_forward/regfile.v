`include "defines.v"

// 寄存器文件：
module regfile (
    input wire rst,
    input wire clk,
    // 数据旁路(数据前推)
    input wire               mem_wreg_i,    // MEM阶段输出
    input wire[`RegAddrBus]  mem_waddr_i,   // MEM阶段输出
    input wire[`RegBus]      mem_wdata_i,   // MEM阶段输出
    input wire               ex_wreg_i,     // EX阶段输出
    input wire[`RegAddrBus]  ex_waddr_i,    // EX阶段输出
    input wire[`RegBus]      ex_wdata_i,    // EX阶段输出

    // 写（写回阶段传递的）
    input wire[`RegAddrBus] waddr,
    input wire[`RegBus]     wdata,
    input wire              we,    //写使能

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

    // Why: 注意，这里0:RegNum-1，这是声明个数，这样写也是可以的
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
        end else if (re1 == `ReadEnable) begin
            /*
                数据转发。
                Think：优先级
                ori $1, $0, 11
                ori $1, $0, 22
                ori $1, $0, 33
                ori $3, $1, 44  //$1，应该是第三条指令的目标寄存器结果，故应该选择最近的数据转发
            */
            if (ex_wreg_i==`WriteEnable && ex_waddr_i==raddr1) begin
                rdata1 <= ex_wdata_i;
            end else if (mem_wreg_i==`WriteEnable && mem_waddr_i==raddr1) begin
                rdata1 <= mem_wdata_i;
            end else if (we == `WriteEnable && raddr1 == waddr) begin   //WB阶段的信息
                //数据转发：译码读、写回阶段写，，写入的是WB阶段的信息
                //此时读与写端口一致，且都使能，那么就直接将写入信息返回给读，当上升沿一到再写。
                rdata1 <= wdata;
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
            /*
                数据转发。
                Think：优先级
                ori $1, $0, 11
                ori $1, $0, 22
                ori $1, $0, 33
                ori $3, $1, 44  //$1，应该是第三条指令的目标寄存器结果，故应该选择最近的数据转发
            */
            if (ex_wreg_i==`WriteEnable && ex_waddr_i==raddr2) begin
                // 数据转发：如果Regfile模块读端⼝1要读取的寄存器就是执⾏阶段要写的⽬的寄存器，那么直接把执⾏阶段的结果ex_wdata_i作为reg1_o的值;
                rdata2 <= ex_wdata_i;
            end else if (mem_wreg_i==`WriteEnable && mem_waddr_i==raddr2) begin
                // 数据转发：访存阶段
                rdata2 <= mem_wdata_i;
            end else if (we == `WriteEnable &&  waddr == raddr2 )begin
                //数据转发：译码读、写回阶段写，此时读与写端口一致，且都使能，那么就直接将写入信息返回给读，当上升沿一到再写。
                rdata2 <= wdata;
            end begin
                // 不存在数据相关，从regfile读
                rdata2 <= regfile[raddr2];
            end
        end else begin
            rdata2 <= `ZeroWord;
        end
    end
    
endmodule