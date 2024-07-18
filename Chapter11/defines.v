
`define RstEnable  1'b1
`define RstDisable 1'b0
`define ZeroWord 32'h00000000
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define ReadEnable 1'b1
`define ReadDisable 1'b0
`define AluOpBus 7:0
`define AluSelBus 2:0
`define InstValid 1'b0
`define InstInvalid 1'b1
`define True_v 1'b1
`define False_v 1'b0
`define ChipEnable 1'b1
`define ChipDisable 1'b0
`define Branch      1'b1
`define MemSelBus   3:0

/*
 * stall[0]  PC
 * stall[1]  IF/ID
 * stall[2]  ID/EX
 * stall[3]  EX/MEM
 * stall[4]  MEM/WB
 * stall[5] Regfile、HiLo
*/
`define StallBus  5:0
`define Stop      1'b1
`define NotStop   1'b0


//指令相关
// 指令码-OP字段
`define OP_ORI    6'b001101
`define OP_ANDI   6'b001100
`define OP_XORI   6'b001110
`define OP_LUI    6'b001111
`define OP_ADDI   6'b001000
`define OP_ADDIU  6'b001001
`define OP_SLTI   6'b001010
`define OP_SLTIU  6'b001011 

`define OP_LB     6'b100000
`define OP_LBU    6'b100100
`define OP_LH     6'b100001
`define OP_LHU    6'b100101
`define OP_LL     6'b110000
`define OP_LW     6'b100011
`define OP_LWL    6'b100010
`define OP_LWR    6'b100110
`define OP_SB     6'b101000
`define OP_SC     6'b111000
`define OP_SH     6'b101001
`define OP_SW     6'b101011
`define OP_SWL    6'b101010
`define OP_SWR    6'b101110

`define CP0MT     11'b01000000100
`define CP0MF     11'b01000000000


`define OP_PREF   6'b110011

// 子功能-FUNC字段
`define FUNC_AND  6'b100100
`define FUNC_OR   6'b100101
`define FUNC_XOR  6'b100110
`define FUNC_NOR  6'b100111

`define FUNC_SLL   6'b000000
`define FUNC_SLLV  6'b000100
`define FUNC_SRL   6'b000010
`define FUNC_SRLV  6'b000110
`define FUNC_SRA   6'b000011
`define FUNC_SRAV  6'b000111
`define FUNC_SYNC  6'b001111
`define FUNC_NOP   6'b000000
`define FUNC_SSNOP 6'b000000

`define FUNC_MOVZ  6'b001010
`define FUNC_MOVN  6'b001011
`define FUNC_MFHI  6'b010000
`define FUNC_MTHI  6'b010001
`define FUNC_MFLO  6'b010010
`define FUNC_MTLO  6'b010011

`define FUNC_SLT   6'b101010
`define FUNC_SLTU  6'b101011
`define FUNC_ADD   6'b100000
`define FUNC_ADDU  6'b100001
`define FUNC_SUB   6'b100010
`define FUNC_SUBU  6'b100011

`define FUNC_CLZ   6'b100000
`define FUNC_CLO   6'b100001

`define FUNC_MULT  6'b011000
`define FUNC_MULTU 6'b011001
`define FUNC_MUL   6'b000010

`define FUNC_MADD  6'b000000
`define FUNC_MADDU 6'b000001
`define FUNC_MSUB  6'b000100
`define FUNC_MSUBU 6'b000101

`define FUNC_DIV   6'b011010
`define FUNC_DIVU  6'b011011

`define OP_J       6'b000010
`define OP_JAL     6'b000011
`define FUNC_JR    6'b001000
`define FUNC_JALR  6'b001001

`define OP_BEQ     6'b000100
`define OP_BGTZ    6'b000111
`define OP_BLEZ    6'b000110
`define OP_BNE     6'b000101

`define RT_BGEZ    5'b00001
`define RT_BGEZAL  5'b10001
`define RT_BLTZ    5'b00000
`define RT_BLTZAL  5'b10000

`define OP_SPECIAL_INST  6'b000000
`define OP_SPECIAL2_INST 6'b011100
`define OP_REGIMM_INST   6'b000001


// AluOp
`define ALU_OR_OP    8'b00100101
`define ALU_AND_OP   8'b00100100
`define ALU_XOR_OP   8'b00100110
`define ALU_NOR_OP   8'b00100111

`define ALU_SLL_OP   8'b01111100
`define ALU_SRL_OP   8'b00000010
`define ALU_SRA_OP   8'b00000011

`define ALU_MOVZ_OP  8'b00001010
`define ALU_MOVN_OP  8'b00001011
`define ALU_MFHI_OP  8'b00010000
`define ALU_MTHI_OP  8'b00010001
`define ALU_MFLO_OP  8'b00010010
`define ALU_MTLO_OP  8'b00010011

`define ALU_SLT_OP   8'b00101010
`define ALU_SLTU_OP  8'b00101011  
`define ALU_ADD_OP   8'b00100000
`define ALU_ADDU_OP  8'b00100001
`define ALU_SUB_OP   8'b00100010
`define ALU_SUBU_OP  8'b00100011
`define ALU_CLZ_OP   8'b10110000
`define ALU_CLO_OP   8'b10110001

`define ALU_MULT_OP  8'b00011000
`define ALU_MULTU_OP 8'b00011001
`define ALU_MUL_OP   8'b10101001

`define ALU_MADD_OP  8'b10100110
`define ALU_MADDU_OP 8'b10101000
`define ALU_MSUB_OP  8'b10101010
`define ALU_MSUBU_OP 8'b10101011

`define ALU_DIV_OP   8'b00011010
`define ALU_DIVU_OP  8'b00011011

`define ALU_J_OP        8'b01001111
`define ALU_JAL_OP      8'b01010000
`define ALU_JR_OP       8'b00001000
`define ALU_JALR_OP     8'b00001001
`define ALU_BEQ_OP      8'b01010001
`define ALU_BGEZ_OP     8'b01000001
`define ALU_BGEZAL_OP   8'b01001011
`define ALU_BGTZ_OP     8'b01010100
`define ALU_BLEZ_OP     8'b01010011
`define ALU_BLTZ_OP     8'b01000000
`define ALU_BLTZAL_OP   8'b01001010
`define ALU_BNE_OP      8'b01010010

`define ALU_LB_OP       8'b11100000
`define ALU_LBU_OP      8'b11100100
`define ALU_LH_OP       8'b11100001
`define ALU_LHU_OP      8'b11100101
`define ALU_LL_OP       8'b11110000
`define ALU_LW_OP       8'b11100011
`define ALU_LWL_OP      8'b11100010
`define ALU_LWR_OP      8'b11100110
`define ALU_PREF_OP     8'b11110011
`define ALU_SB_OP       8'b11101000
`define ALU_SC_OP       8'b11111000
`define ALU_SH_OP       8'b11101001
`define ALU_SW_OP       8'b11101011
`define ALU_SWL_OP      8'b11101010
`define ALU_SWR_OP      8'b11101110

`define ALU_MFC0_OP     8'b01011101
`define ALU_MTC0_OP     8'b01100000


`define ALU_NOP_OP      8'b00000000
// AluSel
`define ALU_RES_LOGIC 3'b001         //逻辑运算
`define ALU_RES_SHIFT 3'b010         //位移运算
`define ALU_RES_MOVE  3'b011	     //移动运算
`define ALU_RES_ARITHMETIC 3'b100	 //算术运算
`define ALU_RES_MUL   3'b101         //乘法（Hi、Lo保存结果）
`define ALU_RES_JUMP_BRANCH 3'b110   //转移类指令
`define ALU_RES_LOAD_STORE  3'b111	 //加载存储指令

`define ALU_RES_NOP   3'b000         

//DIV模块相关
`define DivFree 2'b00 
`define DivByZero 2'b01 
`define DivOn 2'b10 
`define DivEnd 2'b11 
`define DivResultReady 1'b1 
`define DivResultNotReady 1'b0 
`define DivStart 1'b1 
`define DivStop 1'b0


//指令存储器相关
`define InstAddrBus 31:0
`define InstBus 31:0
`define InstMemNum 131071
`define InstMemNumLog2 17

//数据存储器相关
`define DataAddrBus 31:0  //地址总线宽度
`define DataBus     31:0  //数据总线宽度
`define ByteWidth  7:0
`define DataMemNum 131072 //实际容量 131072*4=
`define DataMemNumLog2 17 //实际使⽤的地址宽度，地址总线是19位，低2位片选信号，那么剩下17位就是存储体内定位存储单元了


//ͨ寄存器文件相关
`define RegAddrBus 4:0
`define RegBus 31:0
`define RegWidth 32
`define DoubleRegWidth 64
`define DoubleRegBus 63:0
`define RegNum 32
`define RegNumLog2 5
`define NOPRegAddr 5'b00000

//LLbit
`define LLBitEnable 1'b1;

//CP0
`define CP0_REG_COUNT    5'b01001        
`define CP0_REG_COMPARE  5'b01011      
`define CP0_REG_STATUS   5'b01100       
`define CP0_REG_CAUSE    5'b01101        
`define CP0_REG_EPC      5'b01110          
`define CP0_REG_PrId     5'b01111         
`define CP0_REG_CONFIG   5'b10000 
`define InterruptAssert  1'b1
`define InterruptNotAssert 1'b0

//异常相关
`define ExceptionTypeBus    2:0

`define Exc_Default     3'b000  
`define Exc_InvalidInst 3'b001
`define Exc_Syscall     3'b010
`define Exc_Eret        3'b011

`define Exc_Trap        3'b100
`define Exc_Overflow    3'b101

`define Exc_Interrupt   3'b110