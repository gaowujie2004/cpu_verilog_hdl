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
    output reg[`RegBus]     alu_res_o      //运算结果
);
    reg [`RegBus] logic_res;            //保存逻辑运算结果
    reg [`RegBus] shift_res;            //保存位移运算结果
    wire[4:0]     shift_count = reg2_data_i[4:0];

    // 第一步：根据 aluop_i 运算类型，计算结果
    always @(*) begin
        if (rst == `RstEnable) begin 
            logic_res <= `ZeroWord;
            shift_res <= `ZeroWord;
        end else begin
            case (aluop_i)
                `ALU_OR_OP: begin
                    logic_res <= reg1_data_i | reg2_data_i;
                end
                `ALU_AND_OP: begin
                    logic_res <= reg1_data_i & reg2_data_i;
                end
                `ALU_XOR_OP: begin
                    logic_res <= reg1_data_i ^ reg2_data_i;
                end
                `ALU_NOR_OP: begin
                    logic_res <= ~(reg1_data_i | reg2_data_i);
                end

                `ALU_SLL_OP: begin
                    shift_res <= reg1_data_i << shift_count;    
                end
                `ALU_SRL_OP: begin
                    shift_res <= reg1_data_i >>> shift_count;    
                end
                `ALU_SRA_OP: begin
                    shift_res <= reg1_data_i >>> shift_count;    
                end

                `ALU_NOP_OP: begin
                    logic_res <= `ZeroWord;
                    shift_res <= `ZeroWord;
                end
            endcase
        end
    end

    // 第二步： alusel_i 选择是算术运算还是逻辑运算，选择一个输出
    always @(*) begin
        waddr_o <= waddr_i;
        reg_we_o <= reg_we_i;

        case (alusel_i)
            `ALU_RES_LOGIC: begin
                alu_res_o <= logic_res;
            end
            `ALU_RES_SHIFT: begin
                alu_res_o <= shift_res;
            end
            `ALU_RES_NOP: begin
                alu_res_o <= `ZeroWord;
            end
        endcase
    end

    
endmodule