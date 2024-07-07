
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

`define ALU_NOP_OP   8'b00000000
// AluSel
`define ALU_RES_LOGIC 3'b001         //逻辑运算
`define ALU_RES_SHIFT 3'b010         //位移运算
`define ALU_RES_MOVE  3'b011	     //移动运算
`define ALU_RES_ARITHMETIC 3'b100	 //算术运算
`define ALU_RES_MUL   3'b101         //乘法（Hi、Lo保存结果）

`define ALU_RES_NOP   3'b000         


//指令存储器相关
`define InstAddrBus 31:0
`define InstBus 31:0
`define InstMemNum 131071
`define InstMemNumLog2 17


//ͨ寄存器文件相关
`define RegAddrBus 4:0
`define RegBus 31:0
`define RegWidth 32
`define DoubleRegWidth 64
`define DoubleRegBus 63:0
`define RegNum 32
`define RegNumLog2 5
`define NOPRegAddr 5'b00000
