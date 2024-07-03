// 顶层模块，CPU的管脚
`include "defines.v"

module openmips (
    input wire rst,
    input wire clk,
    input wire[`InstBus] rom_data_i,      // 指令存储器ROM输入的指令字

    output wire rom_ce_o,                 //ROM读使能
    output wire[`InstAddrBus] rom_addr_o, //输出到ROM的地址
);
    // 第一部分：连接各个模块的传送线缆

    // IF阶段
    wire[`InstAddrBus] if_pc;
    pc_reg pc_reg_0(
        .rst(rst),
        .clk(clk),
        .pc(if_pc),
        .ce(rom_ce_o)
    );
    
    assign rom_addr_o = if_pc;  // wire型赋值，必须使用assign。

    // IF_ID寄存器
    wire[`InstAddrBus] id_pc_i;
    wire[`InstBus]     id_inst_i;

    if_id if_id_0(
        .rst(rst), .clk(clk), 
        .if_pc(if_pc),
        .if_inst(rom_data_i), 
        //输出
        .id_pc(id_pc_i), 
        .id_inst(id_inst_i)
    );

    wire[`RegBus] id_reg1_data_i;  //regfile模块输出
    wire[`RegBus] id_reg2_data_i;

    wire[`AluSelBus] id_alusel_o;  //送入流水寄存器
    wire[`AluOpBus] id_aluop_o;
    wire[`RegBus] id_reg1_data_o;
    wire[`RegBus] id_reg2_data_o;
    wire[`RegAddrBus] id_waddr_o;
    wire              id_wreg_o;

    // ID阶段
    wire              id_reg1_read_o;  //送入regfile模块
    wire[`RegAddrBus] id_reg1_addr_o;
    wire              id_reg2_read_o;
    wire[`RegAddrBus] id_reg2_addr_o;
    id id_0(
        .rst(rst), .pc_i(id_pc_i), .inst_i(id_inst_i),
        // regfile模块的输出
        .reg1_data_i(id_reg1_data_i), .reg2_data_i(id_reg2_data_i),
        // 送入流水寄存器
        .alusel_o(id_alusel_o), // 输出
        .aluop_o(id_aluop_o),
        .reg1_data_o(id_reg1_data_o),
        .reg2_data_o(id_reg2_data_o),
        .waddr_o(id_waddr_o),
        .wreg_o(id_wreg_o),
        // 送入regfile模块（读相关）
        .reg1_read_o(id_reg1_read_o),
        .reg1_addr_o(id_reg1_addr_o),
        .reg2_read_o(id_reg2_read_o),
        .reg2_addr_o(id_reg2_addr_o)
    );

    // refile
    wire[`RegAddrBus]  wb_waddr_o;
    wire               wb_we_o;
    wire[`RegBus]      wb_wdata_o;
    regfile regfile_0(
        .rst(rst), .clk(clk),
        .raddr1(id_reg1_addr_o), .re1(id_reg1_read_o), //端口1读
        .raddr2(id_reg2_addr_o), .re2(id_reg2_read_o), //端口2读
        .waddr(wb_waddr_o), .we(wb_we_o), .wdata(wb_wdata_o), //写端口
        //输出
        .rdata1(id_reg1_data_i), .rdata2(id_reg2_data_i)
    );
    
     
    // ID_EX寄存器
    wire[`AluSelBus]  ex_alusel_i;  /*ID/EX流水寄存器输出 && EX输入*/
    wire[`AluOpBus]   ex_aluop_i;
    wire[`RegBus]     ex_reg1_data_i;
    wire[`RegBus]     ex_reg2_data_i;
    wire[`RegAddrBus] ex_waddr_i;
    wire              ex_wreg_i;
    id_ex id_ex_0(
        .rst(rst), .clk(clk), 
        .id_alusel(id_alusel_o), .id_aluop(id_aluop_o), 
        .id_reg1_data(id_reg1_data_o), .id_reg2_data(id_reg2_data_o),
        .id_waddr(id_waddr_o), .id_reg_we(id_wreg_o),
        //输出
        .ex_alusel(ex_alusel_i), .ex_aluop(ex_aluop_i), 
        .ex_reg1_data(ex_reg1_data_i), .ex_reg2_data(ex_reg2_data_i),
        .ex_waddr(ex_waddr_i), .ex_reg_we(ex_wreg_i),
    );


    // EX阶段
    wire[]  ex_waddr_o;
    wire[]  ex_reg_we_o;
    wire[]  ex_alu_res_o;
    ex ex_0(
        .rst(rst),
        .alusel_i(ex_alusel_i), .aluop_i(ex_aluop_i),
        .reg1_data_i(ex_reg1_data_i), .reg1_data_i(ex_reg2_data_i),
        .waddr_i(ex_waddr_i), .reg_we_i(ex_wreg_i),
        //输出
        .waddr_o(ex_waddr_o), .reg_we_o(ex_reg_we_o), .alu_res_o(ex_alu_res_o)
    );


    // EX_MEM寄存器
    wire[`RegAddrBus]  mem_waddr_i;     
    wire               mem_reg_we_i;
    wire[`RegBus]      mem_alu_res_i;
    ex_mem ex_mem_0(
        .rst(rst), .clk(clk),
        .ex_waddr(ex_waddr_o), .ex_reg_we(ex_reg_we_o), .ex_alu_res(ex_alu_res_o),
        //输出
        .mem_waddr(mem_waddr_i), .mem_reg_we(mem_reg_we_i), .mem_alu_res(mem_alu_res_i)
    );

    // MEM阶段
    wire[]  mem_waddr_o;
    wire[]  mem_reg_we_o;
    wire[]  mem_alu_res_o;
    mem mem_0(
        .rst(rst),
        .waddr_i(mem_waddr_i), .reg_we_i(mem_reg_we_i), .alu_res_i(mem_alu_res_i),
        .waddr_o(mem_waddr_o), .reg_we_o(mem_reg_we_o),  .mem_data_o(mem_alu_res_o)
    );

    // MEM_WB寄存器
    mem_wb mem_wb_0(
        .rst(rst), .clk(clk),
        .mem_waddr(mem_waddr_o), .mem_reg_we(mem_reg_we_o), .mem_data(mem_alu_res_o),
        //输出
        .wb_waddr(wb_waddr_o), .wb_reg_we(wb_we_o), .wb_data(wb_wdata_o)
    );


    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            rom_ce_o <= `ReadDisable;
            rom_addr_o <= `ZeroWord;
        end
    end
endmodule

// Why：为什么不写到 always 语句块中了？