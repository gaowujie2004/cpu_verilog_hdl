`include "defines.v"

module ex (
    input wire rst,
    input wire[`AluSelBus]  alusel_i,
    input wire[`AluOpBus]   aluop_i,
    input wire[`RegBus]     reg1_data_i,   //源操作数1
    input wire[`RegBus]     reg2_data_i,   //源操作数2
    input wire[`RegAddrBus] waddr_i,       //目标寄存器地址
    input wire              reg_we_i,      //目标寄存器写使能

    output reg[`RegAddrBus] waddr_o,       //目标寄存器地址
    output reg              reg_we_o,      //目标寄存器写使能
    output reg[`RegBus]     alu_res_o,       //运算结果
);
    reg [`RegBus] logic_res;            //保存逻辑运算结果

    // 第一步：根据 aluop_i 运算类型，计算结果
    always @(*) begin
        if (rst == `RstEnable) begin 
            logic_res <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_OR_OP: begin
                    logic_res <= reg1_data_i | reg2_data_i;
                end

                default: begin
                    logic_res <= `ZeroWord;
                end
            endcase
        end
    end

    // 第二步：多少有点扯淡了，根据 alusel_i 选择是算术运算还是逻辑运算，选择一个输出
    always @(*) begin
        waddr_o <= waddr_i;
        reg_we_o <= reg_we_i;

        case (alusel_i)
            `EXE_RES_LOGIC: begin
                alu_res_o <= logic_res;
            end
            default: 
        endcase
    end

    
endmodule