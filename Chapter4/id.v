`include "defines.v"

// ID译码取操作数阶段：负责取指令操作数，已经生成操作控制信号
module id (
    input wire   rst,
    input wire[`InstAddrBus] pc_i,
    input wire[`InstBus]     inst_i,

    input wire[`RegBus] reg1_data_i,        // 从regfile读的数据
    input wire[`RegBus] reg2_data_i,        // 从regfile读的数据
    
    output reg[`AluSelBus] alusel_o,        // 运算类型？            
    output reg[`AluOpBus]  aluop_o,         // TODO 不太理解运算子类型
    output reg[`RegBus]    reg1_data_o,     // 源操作数1(从regfile模块读取)
    output reg[`RegBus]    reg2_data_o,     // 源操作数2(从regfile模块读取)
    output reg[`RegAddrBus]    waddr_o,     // 目标寄存器地址
    output reg                 wreg_o,      // 写使能
    
    output reg reg1_read_o,                 // reg1读使能
    output reg reg2_read_o,                 // reg2读使能
    output reg[`RegAddrBus]  reg1_addr_o,   // 读reg1寄存器地址
    output reg[`RegAddrBus]  reg2_addr_o    // 读reg2寄存器地址
    // Why: 为什么是reg类型？因为在 always 中赋值，就必须是reg类型，当然综合后可能是连线或寄存器。
);
    wire[5:0] op    = inst_i[31:26];
    wire[5:0] func  = inst_i[5:0];
    wire[`RegAddrBus] rs = inst_i[25:21];
    wire[`RegAddrBus] rt = inst_i[20:16];
    wire[`RegAddrBus] rd = inst_i[15:11];
    wire[15:0]     imm16 = inst_i[15:0];   
    reg[`RegBus] imm32;             // 因为要在 always 语句块中赋值，所以必须是 reg 类型，其实本质上还是wire。
    reg instvalid;                  // 因为要在 always 语句块中赋值，所以必须是 reg 类型，其实本质上还是wire。


    // 第一段：指令译码
    always @(*) begin
        if (rst == `RstEnable) begin
            aluop_o <= `EXE_NOP_OP;
			alusel_o <= `EXE_RES_NOP;
			waddr_o <= `NOPRegAddr;
			wreg_o <= `WriteDisable;
			instvalid <= `InstValid;
			reg1_read_o <= `ReadDisable;
			reg2_read_o <= `ReadDisable;
			reg1_addr_o <= `NOPRegAddr;
			reg2_addr_o <= `NOPRegAddr;
            reg1_data_o <= `ZeroWord;
            reg2_data_o <= `ZeroWord;
			imm32 <= 32'b0;	
        end else begin
            case (op)
                // I型指令：ori $rs, $rt, imm。  R[$rt] <- R[$r]s op u32(imm)
                `EXE_ORI: begin
                    alusel_o  <= `EXE_RES_LOGIC;
                    aluop_o   <= `EXE_OR_OP;
                    waddr_o   <= rt;
                    wreg_o    <= `WriteEnable;
                    instvalid <= 1'b1;

                    // 运算源操作数1提供
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    // 运算源操作数2提供
                    reg2_read_o <= `ReadDisable;    //不读，来源于立即数
                    imm32 = {16'b0, imm16};         //无符号扩展
                end
            endcase
        end
    end

    // 第二段：选择运算源操作数1
    always @(*) begin
        if (rst == `RstEnable) begin
            reg1_data_o <= `ZeroWord;
        end else if (reg1_read_o == `ReadEnable) begin
            reg1_data_o <= reg1_data_i;
        end else begin
            reg1_data_o <= `ZeroWord;
        end
    end

    // 第三段：选择运算源操作数2
    always @(*) begin
        if (rst == `RstEnable) begin
            reg2_data_o <= `ZeroWord;
        end else if (reg2_read_o == `ReadEnable) begin
            reg2_data_o <= reg2_data_i;
        end else if (reg2_read_o == `ReadDisable) begin
            reg2_data_o <= imm32;
        end else begin
            reg2_data_o <= `ZeroWord;
        end
    end

endmodule