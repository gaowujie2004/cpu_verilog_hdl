// 顶层模块，CPU的管脚
`include "defines.v"

module openmips (
    input wire rst,
    input wire clk,
    input wire[`InstBus] rom_data_i,      // 指令存储器ROM输入的指令字

    output wire rom_ce_o,                 //ROM读使能
    output wire[`InstAddrBus] rom_addr_o  //输出到ROM的地址
);
    // 第一部分：连接各个模块的传送线缆
    // stall_ctrl部件
    wire stallreq_from_id;
    wire stallreq_from_ex;
    wire[`StallBus] stall;
    wire[`InstAddrBus] branch_target_address_o;
    wire               branch_flag_o;
    // IF阶段
    wire[`InstAddrBus] if_pc;
    pc_reg pc_reg_0(
        .rst(rst),
        .clk(clk),
        .stall(stall),
        .branch_flag_i(branch_flag_o),
        .branch_target_address_i(branch_target_address_o),
        
        .pc(if_pc),
        .ce(rom_ce_o)
    );
    
    assign rom_addr_o = if_pc;  // TODO：wire型赋值，必须使用assign。

    // IF_ID寄存器
    wire[`InstAddrBus] id_pc_i;
    wire[`InstBus]     id_inst_i;

    if_id if_id_0(
        .rst(rst), .clk(clk), 
        .if_pc(if_pc),
        .if_inst(rom_data_i), 
        .stall(stall),

        //输出
        .id_pc(id_pc_i), 
        .id_inst(id_inst_i)
    );

    stall_ctrl stall_ctrl_0(
        .rst(rst),
        .stallreq_from_id(stallreq_from_id),
        .stallreq_from_ex(stallreq_from_ex),

        .stall(stall)
    );

    // ID阶段      
    wire[`AluSelBus] id_alusel_o;  //送入流水寄存器
    wire[`AluOpBus] id_aluop_o;
    wire[`RegBus] id_reg1_data_o;
    wire[`RegBus] id_reg2_data_o;
    wire[`RegAddrBus] id_waddr_o;
    wire              id_wreg_o;
    wire         id_is_in_delayslot_o; 
    wire[`InstAddrBus] id_link_addr_o;   
    wire  id_next_inst_in_delayslot_o;    


    wire[`RegAddrBus]  ex_waddr_o;     // EX阶段，数据转发
    wire               ex_reg_we_o;
    wire[`RegBus]      ex_alu_res_o;

        
    wire[`RegAddrBus]  mem_waddr_o;    // MEM阶段，数据转发
    wire               mem_reg_we_o;
    wire[`RegBus]      mem_alu_res_o;

    wire[`RegBus] id_reg1_data_i;  //regfile模块输出
    wire[`RegBus] id_reg2_data_i;

    wire              id_reg1_read_o;  //送入regfile模块
    wire[`RegAddrBus] id_reg1_addr_o;
    wire              id_reg2_read_o;
    wire[`RegAddrBus] id_reg2_addr_o;
    wire[`InstBus]    id_inst_o;
    wire              id_ex_is_in_delayslot_o;
    id id_0(
        .rst(rst), .pc_i(id_pc_i), .inst_i(id_inst_i),
        // regfile模块的输出
        .reg1_data_i(id_reg1_data_i), .reg2_data_i(id_reg2_data_i),
        .is_in_delayslot_i(id_ex_is_in_delayslot_o),

        // 输出-送入流水寄存器
        .alusel_o(id_alusel_o), 
        .aluop_o(id_aluop_o),
        .reg1_data_o(id_reg1_data_o),
        .reg2_data_o(id_reg2_data_o),
        .waddr_o(id_waddr_o),
        .wreg_o(id_wreg_o),
        .is_in_delayslot_o(id_is_in_delayslot_o),
        .link_addr_o(id_link_addr_o),
        .next_inst_in_delayslot_o(id_next_inst_in_delayslot_o),
        // 送入regfile模块（读相关）
        .reg1_read_o(id_reg1_read_o),
        .reg1_addr_o(id_reg1_addr_o),
        .reg2_read_o(id_reg2_read_o),
        .reg2_addr_o(id_reg2_addr_o),
        //送入stall_ctrl模块
        .stallreq(stallreq_from_id),
        //调试目的
        .inst_o(id_inst_o),
        //反馈pc
        .branch_flag_o(branch_flag_o),
        .branch_target_o(branch_target_address_o)
    );

    // refile
    wire[`RegAddrBus]  wb_waddr_o;
    wire               wb_we_o;
    wire[`RegBus]      wb_wdata_o;
    wire[`RegBus]      wb_inst_i;
    regfile regfile_0(
        .rst(rst), .clk(clk),
        .wb_inst_i(wb_inst_i),
        .wb_waddr_i(wb_waddr_o), .wb_wreg_i(wb_we_o), .wb_wdata_i(wb_wdata_o), //写端口
        // 数据前推(数据旁路)MEM、ID阶段的结果，也相当于写
        .mem_wreg_i(mem_reg_we_o), .mem_waddr_i(mem_waddr_o), .mem_wdata_i(mem_alu_res_o),
        .ex_wreg_i(ex_reg_we_o),  .ex_waddr_i(ex_waddr_o),  .ex_wdata_i(ex_alu_res_o),
        .raddr1(id_reg1_addr_o), .re1(id_reg1_read_o), //端口1读
        .raddr2(id_reg2_addr_o), .re2(id_reg2_read_o), //端口2读
        //输出
        .rdata1(id_reg1_data_i), .rdata2(id_reg2_data_i)
    );
    
     
    // ID_EX寄存器
    wire[`AluSelBus]  ex_alusel_i; 
    wire[`AluOpBus]   ex_aluop_i;
    wire[`RegBus]     ex_reg1_data_i;
    wire[`RegBus]     ex_reg2_data_i;
    wire[`RegAddrBus] ex_waddr_i;
    wire              ex_wreg_i;
    wire[`InstBus]    ex_inst_i;
    wire              ex_is_indelayslot_i; 
    wire[`InstAddrBus]ex_link_addr_i;
    id_ex id_ex_0(
        .rst(rst), .clk(clk), .id_inst(id_inst_o),
        .stall(stall),
        .id_alusel(id_alusel_o), .id_aluop(id_aluop_o), 
        .id_reg1_data(id_reg1_data_o), .id_reg2_data(id_reg2_data_o),
        .id_waddr(id_waddr_o), .id_reg_we(id_wreg_o),
        .id_is_in_delayslot(id_is_in_delayslot_o), .id_link_address(id_link_addr_o),
        .id_next_inst_in_delayslot(id_next_inst_in_delayslot_o),
        
        .ex_alusel(ex_alusel_i), .ex_aluop(ex_aluop_i), 
        .ex_reg1_data(ex_reg1_data_i), .ex_reg2_data(ex_reg2_data_i),
        .ex_waddr(ex_waddr_i), .ex_reg_we(ex_wreg_i),
        .ex_inst(ex_inst_i),
        .ex_is_indelayslot(ex_is_indelayslot_i), .ex_link_address(ex_link_addr_i),
        .is_in_delayslot(id_ex_is_in_delayslot_o)
    );


    // EX阶段
    wire[`RegBus]    ex_hi_i;
    wire[`RegBus]    ex_lo_i;

    wire             ex_hi_we_o;       //Hi寄存器写使能
    wire             ex_lo_we_o;       //Lo寄存器写使能
    wire[`RegBus]    ex_hi_o;          //指令执行阶段对Hi写入的数据
    wire[`RegBus]    ex_lo_o;          //指令执行阶段对Lo写入的数据
    wire[`RegBus]    ex_inst_o;        //debuger
    wire[1:0]        ex_cnt_o;         //madd(u) msub(u)
    wire[`DoubleRegBus] ex_hilo_temp_o;//madd(u) msub(u)

    wire[1:0]        ex_cnt_i;         //madd(u) msub(u)
    wire[`DoubleRegBus] ex_hilo_temp_i;//madd(u) msub(u)

    wire signed_div_i;
    wire start_i;
    wire[`RegBus] opdata1_i;
    wire[`RegBus] opdata2_i;
    wire[`DoubleRegBus] div_result_o;
    wire                div_ready_o;


    ex ex_0(
        .rst(rst), .inst_i(ex_inst_i),
        .alusel_i(ex_alusel_i), .aluop_i(ex_aluop_i),
        .reg1_data_i(ex_reg1_data_i), .reg2_data_i(ex_reg2_data_i),
        .waddr_i(ex_waddr_i), .reg_we_i(ex_wreg_i),
        .hi_i(ex_hi_i), .lo_i(ex_lo_i),
        .cnt_i(ex_cnt_i), .hilo_temp_i(ex_hilo_temp_i),
        .div_result_i(div_result_o), .div_ready_i(div_ready_o),
        .link_address_i(ex_link_addr_i),
        .is_in_delayslot_i(ex_is_indelayslot_i),

        /*写regfile相关信号*/
        .waddr_o(ex_waddr_o), .reg_we_o(ex_reg_we_o), .alu_res_o(ex_alu_res_o),
        /*写hilo相关信号*/
        .hi_we_o(ex_hi_we_o), .lo_we_o(ex_lo_we_o), .hi_o(ex_hi_o), .lo_o(ex_lo_o),
        /*送入stall_ctrl模块*/
        .stallreq(stallreq_from_ex),
        /*debuger*/
        .inst_o(ex_inst_o),
        /*madd(u) msub(u)*/
        .cnt_o(ex_cnt_o), .hilo_temp_o(ex_hilo_temp_o),
        .div_signed_o(signed_div_i),
        .div_start_o(start_i),
        .div_op1_o(opdata1_i),
        .div_op2_o(opdata2_i)
    );
    div div_0(
    	.clk(clk), .rst(rst),
        .signed_div_i (signed_div_i ),
        .opdata1_i    (opdata1_i    ),
        .opdata2_i    (opdata2_i    ),
        .start_i      (start_i      ),
        .cancel_i     (1'b0         ),
        
        .result_o     (div_result_o ),
        .ready_o      (div_ready_o  )
    );
    


    // EX_MEM寄存器
    wire[`RegAddrBus]  mem_waddr_i;     
    wire               mem_reg_we_i;
    wire[`RegBus]      mem_alu_res_i;
    wire               mem_hi_we_i;     
    wire               mem_lo_we_i;      
    wire[`RegBus]      mem_hi_i;         
    wire[`RegBus]      mem_lo_i;    
    wire[`RegBus]      mem_inst_i;    
    ex_mem ex_mem_0(
        .rst(rst), .clk(clk), 
        .stall(stall),
        .ex_cnt(ex_cnt_o), .ex_hilo_temp(ex_hilo_temp_o),
        .ex_inst(ex_inst_o),
        .ex_waddr(ex_waddr_o), .ex_reg_we(ex_reg_we_o), .ex_alu_res(ex_alu_res_o),
        .ex_hi_we(ex_hi_we_o), .ex_lo_we(ex_lo_we_o), .ex_hi(ex_hi_o), .ex_lo(ex_lo_o),

        .mem_waddr(mem_waddr_i), .mem_reg_we(mem_reg_we_i), .mem_alu_res(mem_alu_res_i),
        .mem_hi_we(mem_hi_we_i), .mem_lo_we(mem_lo_we_i), .mem_hi(mem_hi_i), .mem_lo(mem_lo_i),
        .mem_inst(mem_inst_i),
        /*madd、msub*/
        .cnt_o(ex_cnt_i), .hilo_temp_o(ex_hilo_temp_i)
    );

    // MEM阶段
    wire               mem_hi_we_o;     
    wire               mem_lo_we_o;      
    wire[`RegBus]      mem_hi_o;         
    wire[`RegBus]      mem_lo_o;  
    wire[`RegBus]      mem_inst_o;  
    mem mem_0(
        .rst(rst), 
        .inst_i(mem_inst_i),
        .waddr_i(mem_waddr_i), .reg_we_i(mem_reg_we_i), .alu_res_i(mem_alu_res_i),
        .hi_we_i(mem_hi_we_i), .lo_we_i(mem_lo_we_i), .hi_i(mem_hi_i), .lo_i(mem_lo_i),
        //输出
        .waddr_o(mem_waddr_o), .reg_we_o(mem_reg_we_o),  .mem_data_o(mem_alu_res_o),
        .hi_we_o(mem_hi_we_o), .lo_we_o(mem_lo_we_o), .hi_o(mem_hi_o), .lo_o(mem_lo_o),
        .inst_o(mem_inst_o)
    );

    // MEM_WB寄存器
        /*WB阶段写回HILO*/
    wire            wb_hi_we_i;
    wire            wb_lo_we_i;
    wire[`RegBus]   wb_hi_i;
    wire[`RegBus]   wb_lo_i;
    mem_wb mem_wb_0(
        .rst(rst), .clk(clk),
        .stall(stall),
        .mem_inst(mem_inst_o),
        .mem_waddr(mem_waddr_o), .mem_reg_we(mem_reg_we_o), .mem_data(mem_alu_res_o),
        .mem_hi_we(mem_hi_we_o), .mem_lo_we(mem_lo_we_o), .mem_hi(mem_hi_o), .mem_lo(mem_lo_o),
        //输出
        .wb_waddr(wb_waddr_o), .wb_reg_we(wb_we_o), .wb_data(wb_wdata_o),   //送入regfile
        .wb_hi_we(wb_hi_we_i), .wb_lo_we(wb_lo_we_i), .wb_hi(wb_hi_i), .wb_lo(wb_lo_i), //送入hilo
        .wb_inst(wb_inst_i) //送入regfile、hilo
    );

    hilo hilo_0(
        .rst(rst), .clk(clk),
        .wb_inst_i(wb_inst_i),
        .wb_hi_we_i(wb_hi_we_i), .wb_lo_we_i(wb_lo_we_i), .wb_hi_i(wb_hi_i), .wb_lo_i(wb_lo_i),
        .mem_hi_we_i(mem_hi_we_i), .mem_lo_we_i(mem_lo_we_i), .mem_hi_i(mem_hi_i), .mem_lo_i(mem_lo_i),
        //输出
        .hi_o(ex_hi_i), .lo_o(ex_lo_i)
    );
    
endmodule

// Why：为什么不写到 always 语句块中了？，因为是模块连线，必须在模块顶层。