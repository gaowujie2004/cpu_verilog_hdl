`include "defines.v"

// ID译码取操作数阶段：负责取指令操作数，已经生成操作控制信号
module id (
    input wire   rst,
    input wire[`InstAddrBus] pc_i,
    input wire[`InstBus]     inst_i,

    input wire[`RegBus] reg1_data_i,        // 从regfile读的数据
    input wire[`RegBus] reg2_data_i,        // 从regfile读的数据
    
    // 流水寄存器保存
    output reg[`AluSelBus] alusel_o,        // 运算类型？            
    output reg[`AluOpBus]  aluop_o,         // 运算子类型
    output reg[`RegBus]    reg1_data_o,     // 源操作数1(从regfile模块读取)
    output reg[`RegBus]    reg2_data_o,     // 源操作数2(从regfile模块读取)
    output reg[`RegAddrBus]    waddr_o,     // 目标寄存器地址
    output reg                 wreg_o,      // 写使能
    
    // 传送给Refile模块
    output reg reg1_read_o,                 // reg1读使能
    output reg reg2_read_o,                 // reg2读使能
    output reg[`RegAddrBus]  reg1_addr_o,   // 读reg1寄存器地址
    output reg[`RegAddrBus]  reg2_addr_o,   // 读reg2寄存器地址
    // Why: 为什么是reg类型？因为在 always 中赋值，就必须是reg类型，当然综合后可能是连线或寄存器。

    output    stallreq, 
    
    //调试目的
    output wire[`InstBus] inst_o
);
    wire[5:0] op    = inst_i[31:26];
    wire[5:0] func  = inst_i[5:0];
    wire[`RegAddrBus] rs = inst_i[25:21];
    wire[`RegAddrBus] rt = inst_i[20:16];
    wire[`RegAddrBus] rd = inst_i[15:11];
    wire[4:0]      shamt = inst_i[10:6];
    wire[15:0]     imm16 = inst_i[15:0];   
    reg[`RegBus] imm32;             // 因为要在 always 语句块中赋值，所以必须是 reg 类型，其实本质上还是wire。
    reg instvalid;                  // 因为要在 always 语句块中赋值，所以必须是 reg 类型，其实本质上还是wire。

    // 信号传递
    assign inst_o = inst_i;

    // 第一段：指令译码，各种控制信号
    always @(*) begin
        if (rst == `RstEnable) begin
            aluop_o <= `ALU_NOP_OP;
			alusel_o <= `ALU_RES_NOP;
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
            wreg_o      <= `WriteDisable;
            reg1_read_o <= `ReadDisable;
            reg2_read_o <= `ReadDisable; 

            case (op)
                `OP_SPECIAL_INST: begin             // R型指令
                    if (shamt == 5'b0) begin
                        // 逻辑、reg位移、sync
                        case (func)
                            `FUNC_AND: begin
                                alusel_o  <= `ALU_RES_LOGIC;
                                aluop_o   <= `ALU_AND_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 运算源操作数2提供
                                reg2_read_o <= `ReadEnable; 
                                reg2_addr_o <= rt;
                            end
                            `FUNC_OR: begin
                                alusel_o  <= `ALU_RES_LOGIC;
                                aluop_o   <= `ALU_OR_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 运算源操作数2提供
                                reg2_read_o <= `ReadEnable; 
                                reg2_addr_o <= rt;
                            end
                            `FUNC_XOR: begin
                                alusel_o  <= `ALU_RES_LOGIC;
                                aluop_o   <= `ALU_XOR_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 运算源操作数2提供
                                reg2_read_o <= `ReadEnable; 
                                reg2_addr_o <= rt;
                            end
                            `FUNC_NOR: begin
                                alusel_o  <= `ALU_RES_LOGIC;
                                aluop_o   <= `ALU_NOR_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 运算源操作数2提供
                                reg2_read_o <= `ReadEnable; 
                                reg2_addr_o <= rt;
                            end
                            // 可变位移
                            `FUNC_SLLV: begin
                                alusel_o  <= `ALU_RES_SHIFT;
                                aluop_o   <= `ALU_SLL_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供（位移改变）
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rt;
                                // 运算源操作数2提供（位移改变）
                                reg2_read_o <= `ReadEnable; 
                                reg2_addr_o <= rs;
                            end
                            `FUNC_SRLV: begin
                                alusel_o  <= `ALU_RES_SHIFT;
                                aluop_o   <= `ALU_SRL_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供（位移改变）
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rt;
                                // 运算源操作数2提供（位移改变）
                                reg2_read_o <= `ReadEnable; 
                                reg2_addr_o <= rs;
                            end
                            `FUNC_SRAV: begin
                                alusel_o  <= `ALU_RES_SHIFT;
                                aluop_o   <= `ALU_SRA_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供（位移改变）
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rt;
                                // 运算源操作数2提供（位移改变）
                                reg2_read_o <= `ReadEnable; 
                                reg2_addr_o <= rs;
                            end
                            `FUNC_SYNC, `FUNC_NOP: begin
                                alusel_o  <= `ALU_RES_NOP;
                                aluop_o   <= `ALU_NOP_OP;
                                waddr_o   <= `NOPRegAddr;
                                wreg_o    <= `WriteDisable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供
                                reg1_read_o <= `ReadDisable;
                                // 运算源操作数2提供
                                reg2_read_o <= `ReadDisable; 
                            end

                            `FUNC_MOVN: begin
                                instvalid <= `True_v;
                                alusel_o <= `ALU_RES_MOVE;
                                aluop_o  <= `ALU_MOVN_OP;
                                //写控制
                                waddr_o  <= rd;
                                //Think: 感觉使用reg2_data_o不合理，故而使用reg2_data_i（regfile已经做转发处理了）
                                wreg_o   <= reg2_data_i != `ZeroWord ? `WriteEnable : `WriteDisable;    
                                //读1
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end
                            `FUNC_MOVZ: begin
                                instvalid <= `True_v;
                                alusel_o <= `ALU_RES_MOVE;
                                aluop_o  <= `ALU_MOVZ_OP;
                                //写控制
                                waddr_o  <= rd;
                                //Think: 感觉使用reg2_data_o不合理，故而使用reg2_data_i（regfile已经做转发处理了）
                                wreg_o   <= reg2_data_i == `ZeroWord ? `WriteEnable : `WriteDisable; 
                                //读1
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end

                            `FUNC_MFHI: begin       //mfhi rd, R[rd] <- Hi
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_MOVE;
                                aluop_o   <= `ALU_MFHI_OP;
                                //写控制
                                waddr_o  <= rd;
                                wreg_o   <= `WriteEnable;
                                //读1控制
                                reg1_read_o <= `ReadDisable;
                                //读2控制
                                reg2_read_o <= `ReadDisable;
                            end
                            `FUNC_MFLO: begin       //mflo rd, R[rd] <- Lo
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_MOVE;
                                aluop_o   <= `ALU_MFLO_OP;
                                //写控制
                                waddr_o  <= rd;
                                wreg_o   <= `WriteEnable;
                                //读1控制
                                reg1_read_o <= `ReadDisable;
                                //读2控制
                                reg2_read_o <= `ReadDisable;
                            end
                            `FUNC_MTHI: begin       //mthi rs, Hi <- R[rs]
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_MOVE;
                                aluop_o   <= `ALU_MTHI_OP;
                                //写控制
                                wreg_o   <= `WriteDisable;
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadDisable;
                            end
                            `FUNC_MTLO: begin       //mtlo rs, Lo <- R[rs]
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_MOVE;
                                aluop_o   <= `ALU_MTLO_OP;
                                //写控制
                                wreg_o   <= `WriteDisable;
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadDisable;
                            end

                            /* R[rd] <- R[rs] OP R[rt] */
                            `FUNC_ADD: begin    
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_ADD_OP;
                                //写控制
                                wreg_o    <= `WriteEnable;
                                waddr_o   <= rd;
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end
                            `FUNC_ADDU: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_ADDU_OP;
                                //写控制
                                wreg_o    <= `WriteEnable;
                                waddr_o   <= rd;
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end
                            `FUNC_SUB: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_SUB_OP;
                                //写控制
                                wreg_o    <= `WriteEnable;
                                waddr_o   <= rd;
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;                               
                            end
                            `FUNC_SUBU: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_SUBU_OP;
                                //写控制
                                wreg_o    <= `WriteEnable;
                                waddr_o   <= rd;
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;                               
                            end
                            `FUNC_SLT: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_SLT_OP;
                                //写控制
                                wreg_o    <= `WriteEnable;
                                waddr_o   <= rd;
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;                               
                            end
                            `FUNC_SLTU: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_SLTU_OP;
                                //写控制
                                wreg_o    <= `WriteEnable;
                                waddr_o   <= rd;
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;                               
                            end

                            `FUNC_MULT: begin           //{hi, lo} <- R[rs] * R[rt]，有符号
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_MULT_OP;
                                //写控制
                                wreg_o    <= `WriteDisable; //写Hi、Lo
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;                                   
                            end
                            `FUNC_MULTU: begin           //{hi, lo} <- R[rs] * R[rt]，无符号
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_MULTU_OP;
                                //写控制
                                wreg_o    <= `WriteDisable; //写Hi、Lo
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;                                   
                            end                         

                            default: begin
                                instvalid <= `False_v;
                            end
                        endcase
                    end else begin
                        // imm位移、ssnop
                        case (func)
                            `FUNC_SLL, `FUNC_SSNOP: begin
                                alusel_o  <= `ALU_RES_SHIFT;
                                aluop_o   <= `ALU_SLL_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供（位移改变）
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rt;
                                // 运算源操作数2提供（位移改变）
                                reg2_read_o <= `ReadDisable; //不读寄存器
                                imm32 <= {27'b0, shamt};
                            end
                            `FUNC_SRL: begin   //逻辑右移
                                alusel_o  <= `ALU_RES_SHIFT;
                                aluop_o   <= `ALU_SRL_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供（位移改变）
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rt;
                                // 运算源操作数2提供（位移改变）
                                reg2_read_o <= `ReadDisable; //不读寄存器
                                imm32 <= {27'b0, shamt};
                            end
                            `FUNC_SRA:  begin
                                alusel_o  <= `ALU_RES_SHIFT;
                                aluop_o   <= `ALU_SRA_OP;
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                instvalid <= `True_v;

                                // 运算源操作数1提供（位移改变）
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rt;
                                // 运算源操作数2提供（位移改变）
                                reg2_read_o <= `ReadDisable; //不读寄存器
                                imm32 <= {27'b0, shamt};
                            end

                            default:  begin
                                instvalid <= `False_v;
                            end
                        endcase
                    end
                end
                `OP_SPECIAL2_INST: begin
                    if (shamt == 5'b0) begin
                        case (func)
                            `FUNC_MUL: begin    // R[rd] <- R[rs] ×  R[rt]，低32位写入R[rd]
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_MUL_OP;
                                instvalid <= `True_v;
                                //写控制
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                // 源操作数1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 源操作数2控制
                                reg2_read_o <= `ReadEnable;    //不读，来源于立即数
                                reg2_addr_o <= rt;                              
                            end

                            `FUNC_CLO: begin    // R[rd] <- coun_leading_zeros R[rs]
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_CLO_OP;
                                instvalid <= `True_v;
                                //写控制
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                // 源操作数1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 源操作数2控制
                                reg2_read_o <= `ReadDisable;        
                            end
                            `FUNC_CLZ: begin    // R[rd] <- coun_leading_ones R[rs]
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_CLZ_OP;
                                instvalid <= `True_v;
                                //写控制
                                waddr_o   <= rd;
                                wreg_o    <= `WriteEnable;
                                // 源操作数1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 源操作数2控制
                                reg2_read_o <= `ReadDisable;    
                            end      

                            `FUNC_MADD: begin   //{HI, LO} <- {HI, LO} + rs × rt
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_MADD_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                // 源操作数1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 源操作数2控制
                                reg2_read_o <= `ReadEnable;     
                                reg2_addr_o <= rt;                          
                            end
                            `FUNC_MADDU: begin   //{HI, LO} <- {HI, LO} + r s× rt
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_MADDU_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                // 源操作数1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 源操作数2控制
                                reg2_read_o <= `ReadEnable;     
                                reg2_addr_o <= rt;                               
                            end
                            `FUNC_MSUB: begin   //{HI, LO} <- {HI, LO} - r s× rt
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_MSUB_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                // 源操作数1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 源操作数2控制
                                reg2_read_o <= `ReadEnable;     
                                reg2_addr_o <= rt;                               
                            end 
                            `FUNC_MSUBU: begin   //{HI, LO} <- {HI, LO} + r s× rt
                                alusel_o  <= `ALU_RES_ARITHMETIC;
                                aluop_o   <= `ALU_MSUBU_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                // 源操作数1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                // 源操作数2控制
                                reg2_read_o <= `ReadEnable;     
                                reg2_addr_o <= rt;                               
                            end            
                        endcase
                    end
                end
                /*
                 * I型指令：ori $rs, $rt, imm。  
                 * R[$rt] <- R[$rs] op u32(imm)
                */
                `OP_ORI: begin
                    alusel_o  <= `ALU_RES_LOGIC;
                    aluop_o   <= `ALU_OR_OP;
                    waddr_o   <= rt;
                    wreg_o    <= `WriteEnable;
                    instvalid <= `True_v;

                    // 运算源操作数1提供
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    // 运算源操作数2提供
                    reg2_read_o <= `ReadDisable;    //不读，来源于立即数
                    imm32 = {16'b0, imm16};         //无符号扩展
                end
                `OP_ANDI: begin
                    alusel_o  <= `ALU_RES_LOGIC;
                    aluop_o   <= `ALU_AND_OP;
                    waddr_o   <= rt;
                    wreg_o    <= `WriteEnable;
                    instvalid <= `True_v;

                    // 运算源操作数1提供
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    // 运算源操作数2提供
                    reg2_read_o <= `ReadDisable;    //不读，来源于立即数
                    imm32 = {16'b0, imm16};         //无符号扩展
                end
                `OP_XORI: begin
                    alusel_o  <= `ALU_RES_LOGIC;
                    aluop_o   <= `ALU_XOR_OP;
                    waddr_o   <= rt;
                    wreg_o    <= `WriteEnable;
                    instvalid <= `True_v;

                    // 运算源操作数1提供
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    // 运算源操作数2提供
                    reg2_read_o <= `ReadDisable;    //不读，来源于立即数
                    imm32 = {16'b0, imm16};         //无符号扩展
                end

                `OP_LUI: begin
                    alusel_o  <= `ALU_RES_LOGIC;
                    aluop_o   <= `ALU_OR_OP;
                    waddr_o   <= rt;
                    wreg_o    <= `WriteEnable;
                    instvalid <= `True_v;

                    // 运算源操作数1提供
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;  //00000
                    // 运算源操作数2提供
                    reg2_read_o <= `ReadDisable;    //不读，来源于立即数
                    imm32 = {imm16, 16'b0};
                end

                /* R[rt]  <-  R[rs] OP SignExt(imm16) */
                `OP_ADDI: begin
                    alusel_o  <= `ALU_RES_ARITHMETIC;
                    aluop_o   <= `ALU_ADD_OP;
                    instvalid <= `True_v;
                    //写控制
                    waddr_o   <= rt;
                    wreg_o    <= `WriteEnable;
                    // 源操作数1控制
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    // 源操作数2控制
                    reg2_read_o <= `ReadDisable;    //不读，来源于立即数
                    imm32 <= { {16{imm16[15]}}, imm16 }; //符号扩展
                end
                `OP_ADDIU: begin
                    alusel_o  <= `ALU_RES_ARITHMETIC;
                    aluop_o   <= `ALU_ADDU_OP;
                    instvalid <= `True_v;
                    //写控制
                    waddr_o   <= rt;
                    wreg_o    <= `WriteEnable;
                    // 源操作数1控制
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    // 源操作数2控制
                    reg2_read_o <= `ReadDisable;    //不读，来源于立即数
                    imm32 <= { {16{imm16[15]}}, imm16 }; //符号扩展
                end
                `OP_SLTI: begin
                    alusel_o  <= `ALU_RES_ARITHMETIC;
                    aluop_o   <= `ALU_SLT_OP;
                    instvalid <= `True_v;
                    //写控制
                    waddr_o   <= rt;
                    wreg_o    <= `WriteEnable;
                    // 源操作数1控制
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    // 源操作数2控制
                    reg2_read_o <= `ReadDisable;    //不读，来源于立即数
                    imm32 <= { {16{imm16[15]}}, imm16 }; //符号扩展
                end                
                `OP_SLTIU: begin
                    alusel_o  <= `ALU_RES_ARITHMETIC;
                    aluop_o   <= `ALU_SLTU_OP;
                    instvalid <= `True_v;
                    //写控制
                    waddr_o   <= rt;
                    wreg_o    <= `WriteEnable;
                    // 源操作数1控制
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    // 源操作数2控制
                    reg2_read_o <= `ReadDisable;    //不读，来源于立即数
                    imm32 <= { {16{imm16[15]}}, imm16 }; //符号扩展
                end      

                `OP_PREF: begin
                    alusel_o  <= `ALU_NOP_OP;
                    aluop_o   <= `ALU_RES_NOP;
                    wreg_o    <= `WriteDisable;
                    instvalid <= `True_v;

                    reg1_read_o <= `ReadDisable;
                    reg2_read_o <= `ReadDisable;
                end

                default: begin
                    instvalid <= `False_v;
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