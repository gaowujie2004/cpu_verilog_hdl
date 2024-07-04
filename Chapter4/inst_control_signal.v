// 根据指令字，生成操作控制信号
`include "defines.v"

module inst_control_signal (
    input wire[`InstBus]     inst_i,

    output wire[3:0] aluop,
    output wire alu_src_b, 
    output wire[2:0] branch,    // 条件跳转指令
    output wire[2:0] data_write_sel, // 数据写回选择
    output wire mem_write,
    output wire reg_write,
    
    output wire jmp,
    output wire jr,
    output wire jal
);
    wire[5:0] op    = inst_i[31:26];
    wire[5:0] func  = inst_i[5:0];
    wire[`RegAddrBus] rs = inst_i[25:21];
    wire[`RegAddrBus] rt = inst_i[20:16];
    wire[`RegAddrBus] rd = inst_i[15:11];
    wire[15:0]     imm16 = inst_i[15:0];   
    reg[`RegBus] imm32;             // 因为要在 always 语句块中赋值，所以必须是 reg 类型，其实本质上还是wire。
    reg instvalid;                  // 因为要在 always 语句块中赋值，所以必须是 reg 类型，其实本质上还是wire。


   

endmodule