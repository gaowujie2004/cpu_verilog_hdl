`include "defines.v"

module ex (
    input wire rst,
    input wire[`InstBus]    inst_i,        //用于调试
    input wire[`AluSelBus]  alusel_i,
    input wire[`AluOpBus]   aluop_i,
    input wire[`RegBus]     reg1_data_i,   //源操作数1
    input wire[`RegBus]     reg2_data_i,   //源操作数2
    input wire[`RegAddrBus] waddr_i,       //目标寄存器地址
    input wire              reg_we_i,      //目标寄存器写使能

    input wire[`RegBus]     hi_i,          //Hi寄存器数据
    input wire[`RegBus]     lo_i,          //Lo寄存器数据

    //输出到流水寄存器
    output reg[`RegAddrBus] waddr_o,       //目标寄存器地址
    output reg              reg_we_o,      //目标寄存器写使能
    output reg[`RegBus]     alu_res_o,     //运算结果

    output reg             hi_we_o,       //Hi寄存器写使能
    output reg             lo_we_o,       //Lo寄存器写使能
    output reg[`RegBus]    hi_o,          //指令执行阶段对Hi写入的数据
    output reg[`RegBus]    lo_o           //指令执行阶段对Lo写入的数据
);
    reg [`RegBus] logic_res;            //保存逻辑运算结果
    reg [`RegBus] shift_res;            //保存位移运算结果
    reg [`RegBus] move_res;             //移动操作运算结果
    wire[4:0]     shift_count = reg2_data_i[4:0];

    // 第一步：根据 aluop_i 运算类型，计算结果
    always @(*) begin
        if (rst == `RstEnable) begin 
            logic_res <= `ZeroWord;
            shift_res <= `ZeroWord;
            move_res  <= `ZeroWord;
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
                    shift_res <= reg1_data_i >> shift_count;    
                end
                `ALU_SRA_OP: begin
                    shift_res <= $signed(reg1_data_i) >>> shift_count;
                    // 算术右移
                    // {`RegBus{reg1_data_i[`RegBus-1]}}
                    $display("sra： data1: %h, data2: %h, res: %h", reg1_data_i, shift_count, $signed(reg1_data_i) >>> shift_count);
                end

                `ALU_MOVN_OP, `ALU_MOVZ_OP: begin       // movz rd, rs, rt。 R[rd] <- R[rs]
                    move_res <= reg1_data_i;
                end
                `ALU_MFHI_OP: begin                     // mfhi rd。 R[rd] <- Hi
                    move_res <= hi_i;
                end
                `ALU_MFLO_OP: begin
                    move_res <= lo_i;
                end

                `ALU_NOP_OP: begin
                    logic_res <= `ZeroWord;
                    shift_res <= `ZeroWord;
                    move_res  <= `ZeroWord;
                end

                default: begin
                    logic_res <= `ZeroWord;
                    shift_res <= `ZeroWord;
                    move_res  <= `ZeroWord;
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
            `ALU_RES_MOVE: begin
                alu_res_o <= move_res;
            end
            `ALU_RES_NOP: begin
                alu_res_o <= `ZeroWord;
            end
        endcase
    end

    // 第三步：MTLO、MTHI，需要给出 hi、lo写使能以及写入数据
    // 此信号非传递信号，而是在该阶段产生的
    always @(*) begin
        if (rst == `RstEnable) begin
            hi_we_o <= `WriteDisable;
            hi_o    <= `ZeroWord;
            lo_we_o <= `WriteDisable;
            lo_o    <= `ZeroWord;
        end else begin
            
            case (aluop_i)
                `ALU_MTHI_OP: begin
                    hi_we_o <= `WriteEnable;
                    hi_o    <= reg1_data_i;

                    lo_we_o <= `WriteDisable;
                    lo_o    <= `ZeroWord;
                end

                `ALU_MTLO_OP: begin
                    lo_we_o <= `WriteEnable;
                    lo_o    <= reg1_data_i;

                    hi_we_o <= `WriteDisable;
                    hi_o    <= `ZeroWord;
                end

                default: begin
                    hi_we_o <= `WriteDisable;
                    hi_o    <= `ZeroWord;
                    lo_we_o <= `WriteDisable;
                    lo_o    <= `ZeroWord;
                end
            endcase
        end
    end

    
endmodule