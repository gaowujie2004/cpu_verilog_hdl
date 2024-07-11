`include "defines.v"

module mem (
    input wire rst,
    input wire[`InstBus]    inst_i,        //debuger

    input wire[`RegAddrBus] waddr_i,       //目标寄存器地址
    input wire              reg_we_i,      //目标寄存器写使能
    input wire[`RegBus]     alu_res_i,     //alu运算结果

    input wire             hi_we_i,       //Hi寄存器写使能
    input wire             lo_we_i,       //Lo寄存器写使能
    input wire[`RegBus]    hi_i,          //指令执行阶段对Hi写入的数据
    input wire[`RegBus]    lo_i,          //指令执行阶段对Lo写入的数据

    input wire[`AluOpBus]   aluop_i,
    input wire[`InstAddrBus]mem_addr_i,
    input wire[`RegBus]     reg2_data_i,
    input wire[`RegBus]     mem_data_i,


    //输入流水寄存器
    output reg[`RegAddrBus] waddr_o,       
    output reg              reg_we_o,      
    output reg[`RegBus]     mem_data_o,

    output reg             hi_we_o,       
    output reg             lo_we_o,       
    output reg[`RegBus]    hi_o,          
    output reg[`RegBus]    lo_o,

    output wire[`InstAddrBus]mem_addr_o,
    output reg              mem_we_o,
    output reg              mem_sel_o,   //字节选择
    output reg              mem_ce_o,    //存储器使能控制

    output reg[`InstBus]  inst_o         //debuger
);

    always @(*) begin
        if (rst == `RstEnable) begin
            waddr_o <= `NOPRegAddr;
            reg_we_o <= `WriteDisable;
            mem_data_o <= `ZeroWord;

            hi_we_o   <= `WriteDisable;
            lo_we_o   <= `WriteDisable;
            hi_o      <= `ZeroWord;
            lo_o      <= `ZeroWord;

            inst_o    <= `ZeroWord;
        end else begin
            waddr_o <= waddr_i;
            reg_we_o <= reg_we_i;
            mem_data_o <= alu_res_i;

            hi_we_o   <= hi_we_i;
            lo_we_o   <= lo_we_i;
            hi_o      <= hi_i;
            lo_o      <= lo_i;

            inst_o    <= inst_i;
        end
    end
    
endmodule