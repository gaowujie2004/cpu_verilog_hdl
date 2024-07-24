`include "defines.v"

// ID译码取操作数阶段：负责取指令操作数，已经生成操作控制信号
module id (
    input wire   rst,
    input wire[`InstAddrBus] pc_i,
    input wire[`InstBus]     inst_i,

    input wire[`RegBus] reg1_data_i,        // 从regfile读的数据(最新的数据，已处理过数据相关问题)
    input wire[`RegBus] reg2_data_i,        // 从regfile读的数据(最新的数据，已处理过数据相关问题)

    input wire          is_in_delayslot_i,  // ID/EX输入，当前处于IF阶段的指令是否为延迟槽指令

    input wire[`RegAddrBus]  ex_waddr_i,    // 处于EX阶段的指令
    input wire[`AluOpBus]    ex_aluop_i,    // 处于EX阶段的指令
    
    // 流水寄存器保存
    output reg[`AluSelBus] alusel_o,        // 运算类型？            
    output reg[`AluOpBus]  aluop_o,         // 运算子类型
    output reg[`RegBus]    op1_data_o,      // 源操作数1(refgile模块读取、或立即数)
    output reg[`RegBus]    op2_data_o,      // 源操作数2(从regfile模块读取、或立即数)
    output reg[`RegAddrBus]    waddr_o,     // 目标寄存器地址
    output reg                 wreg_o,      // 写使能

    output reg         is_in_delayslot_o,    // 本阶段生成，当前处于ID阶段的指令是否为延迟槽指令
    output reg[`InstAddrBus] link_addr_o,    // 本阶段生成，跳转指令的返回地址(跳转指令的下一条指令)
    output reg next_inst_in_delayslot_o,     // 本阶段生成，下一条进入IF阶段的指令是否为延迟槽指令
    output reg[`InstAddrBus] branch_target_o,// 本阶段生成->pc.v，转移到的目的地址
    output reg branch_flag_o,                // 本阶段生成->pc.v，是否跳转
    
    
    // 传送给Refile模块
    output reg reg1_read_o,                 // reg1读使能
    output reg reg2_read_o,                 // reg2读使能
    output reg[`RegAddrBus]  reg1_addr_o,   // 读reg1寄存器地址
    output reg[`RegAddrBus]  reg2_addr_o,   // 读reg2寄存器地址
    // Why: 为什么是reg类型？因为在 always 中赋值，就必须是reg类型，当然综合后可能是连线或寄存器。

    output reg stallreq, 

    output wire[`RegBus] reg2_data_o,       // reg2，R[rt]的值，store类指令需要

    // 异常相关
    output wire[`ExceptionTypeBus]  exception_type_o,        //异常信息：低8bit留给外部中断，第8bit表示是否是syscall指令引起的，第9bit表示是否是⽆效指令引起的异常
    output wire[`InstAddrBus]      inst_addr_o,              //ID阶段的指令的地址
    
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
    wire[`InstAddrBus] pc_plus_8   = pc_i + 8;      //延迟槽指令的下一个
    wire[`InstAddrBus] pc_plus_4   = pc_i + 4;      //延迟槽指令
    wire[`InstAddrBus] signed_imm32 = {{16{imm16[15]}}, imm16};
    wire[`InstAddrBus] jump_addr   = {pc_plus_4[31:28], inst_i[25:0], 2'b00};  //{PC+4[31:28],index26,2'b00}
    wire[`InstAddrBus] branch_addr = pc_plus_4 + {signed_imm32[29:0], 2'b00};

    //load-use相关
    reg stallreq_from_reg1_load_relate; //reg1读，但load类型指令写入reg1，数据前推任然解决不了
    reg stallreq_from_reg2_load_relate;
    wire ex_inst_is_load = ((ex_aluop_i == `ALU_LB_OP) || 
                            (ex_aluop_i == `ALU_LBU_OP)||
                            (ex_aluop_i == `ALU_LH_OP) ||
                            (ex_aluop_i == `ALU_LHU_OP)||
                            (ex_aluop_i == `ALU_LW_OP) ||
                            (ex_aluop_i == `ALU_LWR_OP)||
                            (ex_aluop_i == `ALU_LWL_OP)||
                            (ex_aluop_i == `ALU_LL_OP) ||
                            (ex_aluop_i == `ALU_SC_OP)) ? `True_v : `False_v;       //sc会修改R[rt]

    
    reg is_syscall;
    reg is_eret;
    /*
     * 信号传递
    */
    assign inst_o = inst_i;
    assign reg2_data_o = reg2_data_i;
    assign inst_addr_o = pc_i;
    assign exception_type_o = {19'b0, is_eret ,2'b0 ,instvalid ,is_syscall, 8'b0};

    /*
     * 第一段：指令译码，各种控制信号
    */
    always @(*) begin
        if (rst == `RstEnable) begin
            aluop_o <= `ALU_NOP_OP;
			alusel_o <= `ALU_RES_NOP;
			waddr_o <= `NOPRegAddr;
			wreg_o <= `WriteDisable;
			reg1_read_o <= `ReadDisable;
			reg2_read_o <= `ReadDisable;
			reg1_addr_o <= `NOPRegAddr;
			reg2_addr_o <= `NOPRegAddr;
            op1_data_o <= `ZeroWord;
            op2_data_o <= `ZeroWord;
			imm32 <= 32'b0;	     

            is_in_delayslot_o         <= `False_v;
            next_inst_in_delayslot_o  <= `False_v;
            link_addr_o               <= `ZeroWord;
            branch_target_o           <= `ZeroWord;
            branch_flag_o             <= `False_v;

            //异常相关
            is_syscall <= `False_v;
            is_eret    <= `False_v;
			instvalid  <= `False_v;
        end else begin
            // TODO:很重要，case 分支如果未命中，默认逻辑
            wreg_o      <= `WriteDisable;
            reg1_read_o <= `ReadDisable;
            reg2_read_o <= `ReadDisable; 
            aluop_o     <= `ALU_NOP_OP;
            alusel_o    <= `ALU_RES_NOP;
            
            is_in_delayslot_o         <= is_in_delayslot_i;
            next_inst_in_delayslot_o  <= `False_v;
            link_addr_o               <= `ZeroWord;
            branch_target_o           <= `ZeroWord;
            branch_flag_o             <= `False_v;

            //异常相关
            is_syscall <= `False_v;
            is_eret    <= `False_v;
			instvalid  <= `False_v;
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

                            `FUNC_DIV, `FUNC_DIVU: begin          //{hi, lo} <- R[rs] / R[rt]
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_NOP;  //通用寄存器不写
                                aluop_o   <= func==`FUNC_DIV ? `ALU_DIV_OP : `ALU_DIVU_OP;
                                //写控制
                                wreg_o    <= `WriteDisable; //通用寄存器不写
                                //读1控制
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2控制
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;     
                            end                   

                            `FUNC_JR: begin             //jr rs。PC <- R[rs]
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_JUMP_BRANCH; 
                                aluop_o   <= `ALU_JR_OP;
                                //write reg
                                wreg_o    <= `WriteDisable;
                                //read1 reg
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //read2 reg
                                reg2_read_o <= `ReadDisable;
                                //branch
                                next_inst_in_delayslot_o  <= `True_v;    
                                branch_flag_o             <= `True_v;
                                branch_target_o           <= reg1_data_i;
                            end
                            `FUNC_JALR: begin           //jalr rs 或 jalr rd, rs。    R[rd]<-PC+8; PC<-R[rs]
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_JUMP_BRANCH; 
                                aluop_o   <= `ALU_JALR_OP;
                                //write reg
                                wreg_o    <= `WriteEnable;
                                waddr_o   <= rd;
                                //read1 reg
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //read2 reg
                                reg2_read_o <= `ReadDisable;
                                //branch 应该是跳转成功？
                                next_inst_in_delayslot_o  <= `True_v;
                                link_addr_o               <= pc_plus_8;                                
                                branch_target_o           <= reg1_data_i;
                                branch_flag_o             <= `True_v;                           
                            end

                            `FUNC_TEQ: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_NOP; 
                                aluop_o   <= `ALU_SYSCALL_OP;
                                //write reg
                                wreg_o    <= `ReadDisable;
                                //read1 reg
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //read2 reg
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end
                            `FUNC_TGE: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_NOP; 
                                aluop_o   <= `ALU_TGE_OP;
                                //write reg
                                wreg_o    <= `ReadDisable;
                                //read1 reg
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //read2 reg
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end
                            `FUNC_TGEU: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_NOP; 
                                aluop_o   <= `ALU_TGEU_OP;
                                //write reg
                                wreg_o    <= `ReadDisable;
                                //read1 reg
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //read2 reg
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end
                            `FUNC_TLT: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_NOP; 
                                aluop_o   <= `ALU_TLT_OP;
                                //write reg
                                wreg_o    <= `ReadDisable;
                                //read1 reg
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //read2 reg
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end
                            `FUNC_TLTU: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_NOP; 
                                aluop_o   <= `ALU_TLTU_OP;
                                //write reg
                                wreg_o    <= `ReadDisable;
                                //read1 reg
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //read2 reg
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end
                            `FUNC_TNE: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_NOP; 
                                aluop_o   <= `ALU_TNE_OP;
                                //write reg
                                wreg_o    <= `ReadDisable;
                                //read1 reg
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //read2 reg
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;
                            end
                            `FUNC_SYSCALL: begin
                                instvalid <= `True_v;
                                alusel_o  <= `ALU_RES_NOP; 
                                aluop_o   <= `ALU_SYSCALL_OP;
                                //write reg
                                wreg_o    <= `ReadDisable;
                                //read1 reg
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //read2 reg
                                reg2_read_o <= `ReadEnable;
                                reg2_addr_o <= rt;  
                                //syscall
                                is_syscall  <= `True_v;
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
                `OP_REGIMM_INST: begin
                    if (rt == `RT_BLTZ) begin       //R[rs]<0 then branch
                        instvalid <= `True_v;
                        alusel_o  <= `ALU_RES_JUMP_BRANCH;
                        aluop_o   <= `ALU_BLTZ_OP;
                        //write
                        wreg_o    <= `WriteDisable;
                        //read1 reg
                        reg1_read_o <= `ReadEnable;
                        reg1_addr_o <= rs;
                        //read2 reg
                        reg2_read_o <= `ReadDisable;   
                        //branch
                        if (reg1_data_i[31]) begin
                            next_inst_in_delayslot_o <= `True_v;
                            branch_flag_o            <= `True_v;    //reg_data_i有符号数，如果小于0，那么符号位为1        
                            branch_target_o          <= branch_addr;
                        end
                         
                    end else if(rt == `RT_BLTZAL) begin     //R[rs]<0 then branch  。 总会R[$31]<-PC+8
                        instvalid <= `True_v;
                        alusel_o  <= `ALU_RES_JUMP_BRANCH;
                        aluop_o   <= `ALU_BLTZAL_OP;
                        //write
                        wreg_o    <= `WriteEnable;
                        waddr_o   <= `RegNumLog2'h1f;
                        //read1 reg
                        reg1_read_o <= `ReadEnable;
                        reg1_addr_o <= rs;
                        //read2 reg
                        reg2_read_o <= `ReadDisable;   
                        //branch
                        link_addr_o              <= pc_plus_8;
                        if (reg1_data_i[31]) begin
                            next_inst_in_delayslot_o <= `True_v;
                            branch_flag_o            <= `True_v;    //reg_data_i有符号数，如果小于0，那么符号位为1        
                            branch_target_o          <= branch_addr;
                        end
                    end else if (rt == `RT_BGEZ) begin
                        /*
                         * if (R[rs] >= 0) then branch
                        */
                        instvalid <= `True_v;
                        alusel_o  <= `ALU_RES_JUMP_BRANCH;
                        aluop_o   <= `ALU_BGEZ_OP;
                        //write
                        wreg_o    <= `WriteDisable;
                        //read1 reg
                        reg1_read_o <= `ReadEnable;
                        reg1_addr_o <= rs;
                        //read2 reg
                        reg2_read_o <= `ReadDisable;   
                        //TODO: branch
                        if (~reg1_data_i[31]) begin     //reg_data_i有符号数，那么符号位为0，那就是 >=0
                            next_inst_in_delayslot_o <= `True_v;
                            branch_flag_o            <= `True_v;                     
                            branch_target_o          <= branch_addr;
                        end
                    end else if (rt == `RT_BGEZAL) begin
                        /* if (R[rs] >= 0) then branch  . 总会R[$31]<-PC+8    */
                        instvalid <= `True_v;
                        alusel_o  <= `ALU_RES_JUMP_BRANCH;
                        aluop_o   <= `ALU_BGEZAL_OP;
                        //write
                        wreg_o    <= `WriteEnable;
                        waddr_o   <= `RegNumLog2'h1f;
                        //read1 reg
                        reg1_read_o <= `ReadEnable;
                        reg1_addr_o <= rs;
                        //read2 reg
                        reg2_read_o <= `ReadDisable;   
                        //branch
                        link_addr_o                  <= pc_plus_8;      //延迟槽指令被执行了，故pc+8
                        if (~reg1_data_i[31]) begin     //reg_data_i有符号数，那么符号位为0，那就是 >=0
                            next_inst_in_delayslot_o <= `True_v;
                            branch_flag_o            <= `True_v;                     
                            branch_target_o          <= branch_addr;
                        end                       
                    end

                    case (rt)
                        // teqi rs, imm16
                        //if GPR[rs] = sign_extended(immediate) then trap，
                        `RT_TEQI: begin
                                alusel_o  <= `ALU_RES_NOP;
                                aluop_o   <= `ALU_TEQ_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                //读1
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2
                                reg2_read_o <= `ReadDisable;     
                                imm32 <= signed_imm32;
                        end
                        `RT_TGEI: begin
                                alusel_o  <= `ALU_RES_NOP;
                                aluop_o   <= `ALU_TGE_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                //读1
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2
                                reg2_read_o <= `ReadDisable;     
                                imm32 <= signed_imm32;
                        end
                        `RT_TGEIU: begin
                                alusel_o  <= `ALU_RES_NOP;
                                aluop_o   <= `ALU_TGEU_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                //读1
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2
                                reg2_read_o <= `ReadDisable;     
                                imm32 <= signed_imm32;
                        end
                        `RT_TLTI: begin
                                alusel_o  <= `ALU_RES_NOP;
                                aluop_o   <= `ALU_TLT_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                //读1
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2
                                reg2_read_o <= `ReadDisable;     
                                imm32 <= signed_imm32;
                        end
                        `RT_TLTIU: begin
                                alusel_o  <= `ALU_RES_NOP;
                                aluop_o   <= `ALU_TLTU_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                //读1
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2
                                reg2_read_o <= `ReadDisable;     
                                imm32 <= signed_imm32;
                        end
                        `RT_TNEI: begin
                                alusel_o  <= `ALU_RES_NOP;
                                aluop_o   <= `ALU_TNE_OP;
                                instvalid <= `True_v;
                                //写控制
                                wreg_o    <= `WriteDisable;
                                //读1
                                reg1_read_o <= `ReadEnable;
                                reg1_addr_o <= rs;
                                //读2
                                reg2_read_o <= `ReadDisable;     
                                imm32 <= signed_imm32;
                        end
                    endcase
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
                
                /*
                 * Desc: J instr_index
                 * RTL:  PC <- {PC+4[31:28],instr_index26,2'b00}
                */
                `OP_J: begin    
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_JUMP_BRANCH;
                    aluop_o   <= `ALU_J_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //read1 reg
                    reg1_read_o <= `ReadDisable;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;
                    //branch 
                    next_inst_in_delayslot_o  <= `True_v;
                    branch_flag_o             <= `True_v;
                    branch_target_o           <= jump_addr;
                end
                /*
                 * Desc: jal instr_index
                 * RTL:  R[$31]<-PC+4； PC<-{PC+4[31:28],instr_index26,2'b00}
                */
                `OP_JAL: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_JUMP_BRANCH;
                    aluop_o   <= `ALU_JAL_OP;
                    //write
                    wreg_o    <= `WriteEnable;
                    waddr_o   <= `RegNumLog2'h1f;
                    //read1 reg
                    reg1_read_o <= `ReadDisable;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;     
                    //branch
                    next_inst_in_delayslot_o <= `True_v;
                    link_addr_o              <= pc_plus_8;         //Think:又冗余一个ALU add， Why: 延迟槽所以+8？无论如何都会先把延迟槽指令执行完，所以返回地址不能是延迟槽指令了
                    branch_target_o          <= jump_addr;
                    branch_flag_o            <= `True_v;
                end
                
                /*
                 * 条件转移指令
                 * 我们在ID阶段进行比较，没有在EX阶段复用硬件资源，但好处是减少时钟周期浪费
                */
                `OP_BEQ: begin                        //beq rs,rt,offset。 R[rs]==R[rt] then branch
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_JUMP_BRANCH;
                    aluop_o   <= `ALU_BEQ_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadEnable;   
                    reg2_addr_o <= rt;
                    //branch
                    if (reg1_data_i == reg2_data_i) begin
                        next_inst_in_delayslot_o <= `True_v;
                        branch_target_o          <= branch_addr;
                        branch_flag_o            <= `True_v;
                        // TODO: 这样一来，延迟槽指令怎么执行？暂停一个CLK吗？
                    end
                end
                `OP_BNE: begin                       //bne rs,rt,offset。   R[rs]!=R[rt] then branch
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_JUMP_BRANCH;
                    aluop_o   <= `ALU_BNE_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadEnable;   
                    reg2_addr_o <= rt;
                    //branch
                    if (reg1_data_i != reg2_data_i) begin
                        next_inst_in_delayslot_o <= `True_v;
                        branch_target_o          <= branch_addr;
                        branch_flag_o            <= `True_v;
                    end                                    
                end
                `OP_BGTZ: begin                        //bgtz rs,offset。  R[rs]>0 then branch
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_JUMP_BRANCH;
                    aluop_o   <= `ALU_BGTZ_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;   
                    //branch
                    if ($signed(reg1_data_i) > 0) begin
                        next_inst_in_delayslot_o <= `True_v;
                        branch_target_o          <= branch_addr;
                        branch_flag_o            <= `True_v;                             
                    end
                end
                `OP_BLEZ: begin                       //blez rs,offset。    R[rs]<=0 then branch
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_JUMP_BRANCH;
                    aluop_o   <= `ALU_BLEZ_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;   
                    //branch
                    if (reg1_data_i[31] || (reg1_data_i == `ZeroWord)) begin
                        next_inst_in_delayslot_o <= `True_v;
                        branch_target_o          <= branch_addr;
                        branch_flag_o            <= `True_v;                           
                    end
                end


                /*
                 * 内存地址：R[rs]+signedExt(imm16) ，EX阶段计算内存地址。
                 * 目的寄存器：R[rt]
                */
                `OP_LB: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_LB_OP;
                    //write
                    wreg_o    <= `WriteEnable;
                    waddr_o   <= rt;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;
                    imm32       <= signed_imm32;
                end
                `OP_LBU: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_LBU_OP;
                    //write
                    wreg_o    <= `WriteEnable;
                    waddr_o   <= rt;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;
                    imm32       <= signed_imm32;                    
                end
                `OP_LH: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_LH_OP;
                    //write
                    wreg_o    <= `WriteEnable;
                    waddr_o   <= rt;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;
                    imm32       <= signed_imm32;                         
                end
                `OP_LHU: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_LHU_OP;
                    //write
                    wreg_o    <= `WriteEnable;
                    waddr_o   <= rt;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;
                    imm32       <= signed_imm32;                     
                end
                `OP_LL: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_LL_OP;
                    //write
                    wreg_o    <= `WriteEnable;
                    waddr_o   <= rt;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;
                    imm32       <= signed_imm32;                       
                end
                `OP_LW: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_LW_OP;
                    //write
                    wreg_o    <= `WriteEnable;
                    waddr_o   <= rt;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadDisable;
                    imm32       <= signed_imm32;                         
                end
                `OP_LWL: begin                          //Think: 有些特殊，R[rt]某些位是不改变的，故需要读一下rt
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_LWL_OP;
                    //write
                    wreg_o    <= `WriteEnable;
                    waddr_o   <= rt;
                    //read1 reg
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //read2 reg
                    reg2_read_o <= `ReadEnable;
                    reg2_addr_o <= rt;
                    imm32       <= signed_imm32;                        
                end
                `OP_LWR: begin                          //Think: 有些特殊，R[rt]某些位是不改变的，故需要读一下rt
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_LWR_OP;
                    //write
                    wreg_o    <= `WriteEnable;
                    waddr_o   <= rt;
                    //reg1
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //reg2
                    reg2_read_o <= `ReadEnable;
                    reg2_addr_o <= rt;
                    imm32       <= signed_imm32;                         
                end

                /*
                 * target_addr：R[rs]+signedExt(imm16) ，EX阶段计算内存地址。
                 * M[target_addr] <- R[rt] 
                */
                `OP_SB: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_SB_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //reg1
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //reg2
                    reg2_read_o <= `ReadEnable;
                    reg2_addr_o <= rt;
                    imm32       <= signed_imm32;              
                end
                `OP_SC: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_SC_OP;
                    //write
                    wreg_o    <= `WriteEnable; //与其他的store指令的区别
                    //reg1
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //reg2
                    reg2_read_o <= `ReadEnable;
                    reg2_addr_o <= rt;
                    imm32       <= signed_imm32;                       
                end
                `OP_SH: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_SH_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //reg1
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //reg2
                    reg2_read_o <= `ReadEnable;
                    reg2_addr_o <= rt;
                    imm32       <= signed_imm32;                              
                end
                `OP_SW: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_SW_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //reg1
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //reg2
                    reg2_read_o <= `ReadEnable;
                    reg2_addr_o <= rt;
                    imm32       <= signed_imm32;                      
                end
                `OP_SWL: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_SWL_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //reg1
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //reg2
                    reg2_read_o <= `ReadEnable;
                    reg2_addr_o <= rt;
                    imm32       <= signed_imm32;                        
                end
                `OP_SWR: begin
                    instvalid <= `True_v;
                    alusel_o  <= `ALU_RES_LOAD_STORE;
                    aluop_o   <= `ALU_SWR_OP;
                    //write
                    wreg_o    <= `WriteDisable;
                    //reg1
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    //reg2
                    reg2_read_o <= `ReadEnable;
                    reg2_addr_o <= rt;
                    imm32       <= signed_imm32;                         
                end

                
                default: begin
                    instvalid <= `False_v;
                end
            endcase

            
            if (inst_i[31:21] == 11'b01000000000 && inst_i[10:0] == 11'b00000000000) begin
                /*
                 * Desc: mfc0 rt, rd
                 * RTL:  GPR[rt] <- CPR[0,rd]
                */
                instvalid <= `True_v;
                alusel_o  <= `ALU_RES_MOVE;
                aluop_o   <= `ALU_MFC0_OP;
                //write
                wreg_o    <= `WriteEnable;
                waddr_o   <= rt;
                //read1 reg
                reg1_read_o <= `ReadDisable;
                //read2 reg
                reg2_read_o <= `ReadDisable;
            end else if (inst_i[31:21] == 11'b01000000100 && inst_i[10:0] == 11'b00000000000) begin
                /*
                 * Desc: mtc0 rt, rd
                 * RTL:  CPR[0,rd] <- GPR[rt]
                */
                instvalid <= `True_v;
                alusel_o  <= `ALU_RES_MOVE;
                aluop_o   <= `ALU_MTC0_OP;
                //write
                wreg_o    <= `WriteDisable;
                //read1 reg
                reg1_read_o <= `ReadDisable;
                //read2 reg
                reg2_read_o <= `ReadEnable;
                reg2_addr_o <= rt;
            end else if (inst_i == `INST_ERET) begin
                instvalid <= `True_v;
                alusel_o  <= `ALU_RES_NOP;
                aluop_o   <= `ALU_ERET_OP;
                //write
                wreg_o      <= `WriteDisable;
                //read1 reg
                reg1_read_o <= `ReadDisable;
                //read2 reg
                reg2_read_o <= `ReadDisable;
                //eret
                is_eret     <= `True_v;
            end
        end
    end
    
    /*
     * 第二段：选择运算源操作数1
    */
    always @(*) begin
        stallreq_from_reg1_load_relate  <= `NotStop;
        if (rst == `RstEnable) begin
            op1_data_o <= `ZeroWord;
        end else if (reg1_read_o == `ReadEnable) begin
            if (ex_inst_is_load==`True_v  && ex_waddr_i==reg1_addr_o) begin
                //load-use数据相关，那就会写目标寄存器
                stallreq_from_reg1_load_relate <= `Stop;
            end
            op1_data_o <= reg1_data_i;
        end else begin
            op1_data_o <= `ZeroWord;
        end
    end

    /*
     * 第三段：选择运算源操作数2
    */
    always @(*) begin
        stallreq_from_reg2_load_relate  <= `NotStop;
        if (rst == `RstEnable) begin
            op2_data_o <= `ZeroWord;
        end else if (reg2_read_o == `ReadEnable) begin
            /*
             * load、store要计算地址，第二操作数应该为立即数
             * 但与此同时，LWR、LWL与store类指令都需要R[rt]的值，故reg2_read_o这种情况为ReadEnable
            */
            if (alusel_o == `ALU_RES_LOAD_STORE) begin
                op2_data_o <= imm32;
            end else begin
                op2_data_o <= reg2_data_i;
            end
            if (ex_inst_is_load==`True_v && ex_waddr_i==reg2_addr_o) begin
                //load-use数据相关，那就会写目标寄存器
                stallreq_from_reg2_load_relate <= `True_v;
            end 
        end else if (reg2_read_o == `ReadDisable) begin
            op2_data_o <= imm32;
        end else begin
            op2_data_o <= `ZeroWord;
        end
    end

    always @(*) begin
        stallreq <= stallreq_from_reg1_load_relate || stallreq_from_reg2_load_relate;
    end

endmodule