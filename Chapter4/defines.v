
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
`define EXE_ORI  6'b001101
`define EXE_NOP  6'b000000


// AluOp
`define EXE_OR_OP    8'b00100101
`define EXE_NOP_OP   8'b00000000
// AluSel
`define EXE_RES_LOGIC 3'b001            //逻辑运算
`define EXE_RES_NOP 3'b000              


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
