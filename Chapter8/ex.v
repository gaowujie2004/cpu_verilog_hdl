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

    input wire[1:0]         cnt_i,         //累加乘、累加减使用，第几个周期
    input wire[`DoubleRegBus] hilo_temp_i, //累加乘、累加减使用，相乘的中间结果

    input wire[`DoubleRegBus] div_result_i, //div指令结果
    input wire                div_ready_i,  //div模块是否可读

    input wire                is_in_delayslot_i,    //延迟槽指令
    input wire                link_address_i,       //保存的返回地址

    //输出到流水寄存器
    output reg[`RegAddrBus] waddr_o,       //目标寄存器地址
    output reg              reg_we_o,      //目标寄存器写使能
    output reg[`RegBus]     alu_res_o,     //运算结果

    output reg             hi_we_o,       //Hi寄存器写使能
    output reg             lo_we_o,       //Lo寄存器写使能
    output reg[`RegBus]    hi_o,          //指令执行阶段对Hi写入的数据
    output reg[`RegBus]    lo_o,          //指令执行阶段对Lo写入的数据

    output reg              stallreq,

    output reg[1:0]         cnt_o,         //第几周期
    output reg[`DoubleRegBus] hilo_temp_o, //相乘中间结果

    output wire[`InstBus]  inst_o,         //用于调试

    output wire            div_signed_o,   //是否有符号div
    output wire[`RegBus]   div_op1_o,      //被除数
    output wire[`RegBus]   div_op2_o,      //除数
    output reg             div_start_o     //div开始工作
);
    reg [`RegBus] logic_res;            //保存逻辑运算结果
    reg [`RegBus] shift_res;            //保存位移运算结果
    reg [`RegBus] move_res;             //移动操作运算结果
    reg [`RegBus] arithmetic_res;       //算术操作运算结果
    wire[4:0]     shift_count = reg2_data_i[4:0];

    assign inst_o = inst_i;

    /* 计算：逻辑、位移、移动运算结果 */
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



    /*
     * 计算：简单算术运算结果
    */
    wire xF=reg1_data_i[`RegWidth-1];
    wire yF=reg2_data_i[`RegWidth-1];
    reg  sumF;
    reg  of = `False_v;                  //溢出判断
    reg signed[6:0] i;                   //0~31是正数
    always @(*) begin
        if (rst ==`RstEnable) begin
            arithmetic_res = `ZeroWord;
        end else begin
            case (aluop_i)
                `ALU_ADD_OP: begin
                    arithmetic_res = reg1_data_i + reg2_data_i;
                    // TODO:溢出则不赋值，且产生中断
                    // +、+、-，溢出，0、0、1
                    // -、-、+，溢出，1、1、0
                    sumF = arithmetic_res[`RegWidth-1];
                    of = (~xF & ~yF & sumF) | (xF & yF & ~sumF);
                end

                `ALU_ADDU_OP: begin
                    arithmetic_res  <= reg1_data_i + reg2_data_i;
                end

                `ALU_SUB_OP: begin
                    arithmetic_res = reg1_data_i - reg2_data_i;
                    // TODO: 溢出则不赋值，且产生中断
                    // +、-，转为加，+ +，可能溢出。   +、-， - ，溢出。  0、1、1  ~xf & yf & sf
                    // -、+，转为加，- -， 可能溢出。  -、+、+，  溢出。  1  0 0  xf & ~yf & ~sf
                    // -、-，转为加，- +，不可能溢出
                    // +、+，转为加，+ -，不可能溢出
                    sumF = arithmetic_res[`RegWidth-1];
                    of = (~xF & yF & sumF) | (xF & ~yF & ~sumF);
                end

                `ALU_SUBU_OP: begin
                    arithmetic_res <= reg1_data_i - reg2_data_i;
                end

                `ALU_MUL_OP: begin          //R[rd] <- R[rs] ×  R[rt]，有符号相乘低32位放入R[rd]
                    arithmetic_res <= $signed(reg1_data_i) * $signed(reg2_data_i);
                end

                `ALU_SLT_OP: begin          //R[rt] <-  reg1<reg2 ? 1 : 0，有符号比较
                    arithmetic_res <= $signed(reg1_data_i) < $signed(reg2_data_i);
                end

                `ALU_SLTU_OP: begin         //R[rt] <-  rs<SignExt(imm16) ? 1 : 0，无符号比较
                    arithmetic_res <= reg1_data_i < reg2_data_i;
                end

                `ALU_CLZ_OP: begin          //R[rd] <- coun_leading_zeros R[rs]，从高位到低位有多少个连续的0
                    arithmetic_res=0;
                    for(i=6'd31; i>=0 && !reg1_data_i[i]; i=i-1) begin
                        arithmetic_res = arithmetic_res + 1;
                    end
                end

                `ALU_CLO_OP: begin          //R[rd] <- coun_leading_ones R[rs]，从高位到低位有多少个连续的1
                    arithmetic_res=0;
                    for(i=6'd31; i>=0 && reg1_data_i[i]; i=i-1) begin
                        arithmetic_res = arithmetic_res + 1;
                    end
                end 
            endcase
        end
    end

    /*
     * Write Regfile选择结果：根据alusel_i选择运算结果输出
    */
    always @(*) begin
        waddr_o <= waddr_i;
        if ((aluop_i == `ALU_ADD_OP || aluop_i == `ALU_SUB_OP ) && of) begin
            reg_we_o <= `WriteDisable;
            // TODO: 遗留项，后续还会触发中断
        end else begin
            reg_we_o <= reg_we_i;
        end

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

            `ALU_RES_ARITHMETIC: begin
                alu_res_o <= arithmetic_res;
            end

            `ALU_RES_NOP: begin
                alu_res_o <= `ZeroWord;
            end
        endcase
    end


    /*
     * 计算：madd、maddu、msub、msubu
    */
    reg[`DoubleRegBus] madd_msub_hilo_data;
    reg                madd_msub_hilo_we;
    reg                stallreq_from_madd_msub;
    always @(*) begin
        if (rst == `RstEnable) begin
            cnt_o       <= 2'b00;
            hilo_temp_o <= {`ZeroWord, `ZeroWord};
            stallreq_from_madd_msub <= `NotStop;
        end else if (aluop_i==`ALU_MADD_OP || aluop_i==`ALU_MADDU_OP || aluop_i==`ALU_MSUB_OP || aluop_i==`ALU_MSUBU_OP) begin
            if (cnt_i==2'b00) begin
                //第一个时钟周期
                if (aluop_i==`ALU_MADD_OP || aluop_i==`ALU_MSUB_OP) begin
                    hilo_temp_o <=  $signed(reg1_data_i)*$signed(reg2_data_i);
                end else begin
                    hilo_temp_o <=  reg1_data_i*reg2_data_i;
                end

                madd_msub_hilo_we       <= `WriteDisable;
                cnt_o                   <= 2'b01;
                stallreq_from_madd_msub <= `Stop;
            end else if (cnt_i == 2'b01) begin
                //第二个时钟周期
                if (aluop_i==`ALU_MADD_OP || aluop_i==`ALU_MADDU_OP) begin
                   madd_msub_hilo_data <= {hi_i, lo_i} + hilo_temp_i;
                end else begin
                   madd_msub_hilo_data <= {hi_i, lo_i} - hilo_temp_i;
                end

                madd_msub_hilo_we       <= `WriteEnable;
                //Why: 很重要如果因其他原因导致流⽔线保持暂停，那么由于cnt_o为2'b10，所以EX阶段不再计算，从⽽防⽌乘累加指令重复运⾏。
                cnt_o                   <= 2'b10;  
                stallreq_from_madd_msub <= `NotStop;
            end
        end else begin
            cnt_o                   <= 2'b00;
            stallreq_from_madd_msub <= `NotStop;
            hilo_temp_o             <= {`ZeroWord, `ZeroWord};
        end
    end

    /*
     * 计算：div、divu
    */
    assign div_op1_o = reg1_data_i;
    assign div_op2_o = reg2_data_i;
    assign div_signed_o = aluop_i==`ALU_DIV_OP;
    reg stallreq_from_div;
    reg div_hilo_we;
    always @(*) begin
        if (rst == `RstEnable) begin
            stallreq_from_div <= `NotStop;
            div_start_o       <= `DivStop;
        end else begin
            if (aluop_i==`ALU_DIV_OP || aluop_i==`ALU_DIVU_OP) begin
                if (div_ready_i == `DivResultReady) begin
                    div_start_o       <= `DivStop;
                    stallreq_from_div <= `NotStop;
                    div_hilo_we       <= `WriteEnable;
                end else begin
                    div_start_o       <= `DivStart;
                    stallreq_from_div <= `Stop;
                    div_hilo_we       <= `WriteDisable;
                end
            end else begin
                stallreq_from_div <= `NotStop;
			    div_start_o       <= `DivStop;
            end
        end
    end

    /*
     * Hi、Lo、HiLo_WE，信号生成
     * 此信号非传递信号，而是在该阶段产生的
    */
    always @(*) begin
        if (rst == `RstEnable) begin
            hi_we_o <= `WriteDisable;
            hi_o    <= `ZeroWord;
            lo_we_o <= `WriteDisable;
            lo_o    <= `ZeroWord;
        end else begin
            case (aluop_i)
                /*
                 * HiLo Move Regfile
                 * RTL: Hi/Lo <- R[rs]
                */
                `ALU_MTHI_OP: begin             //mthi rs。hi <- R[rs]
                    hi_we_o <= `WriteEnable;
                    hi_o    <= reg1_data_i;
                    lo_we_o <= `WriteDisable;
                    lo_o    <= `ZeroWord;
                end
                `ALU_MTLO_OP: begin
                    lo_we_o <= `WriteEnable;    //mtlo rs。lo <- R[rs]
                    lo_o    <= reg1_data_i;
                    hi_we_o <= `WriteDisable;
                    hi_o    <= `ZeroWord;
                end


                /*
                 * mult、multu
                 * RTL: {hi,lo} <- R[rs]*R[rt]
                */
                `ALU_MULT_OP: begin         //{hi, lo} <- rs × rt，有符号
                    {hi_o, lo_o} <= $signed(reg1_data_i)  * $signed(reg2_data_i);
                    hi_we_o <= `WriteEnable;
                    lo_we_o <= `WriteEnable;
                end
                `ALU_MULTU_OP: begin        //{hi, lo} <- rs × rt，无符号
                    {hi_o, lo_o} <= (reg1_data_i)  * (reg2_data_i);
                    hi_we_o <= `WriteEnable;
                    lo_we_o <= `WriteEnable;
                end


                /*
                 * madd、maddu、msub、msubu
                 * RTL: {Hi,Lo} <- {Hi,Lo} +/- rs*rt
                */
                `ALU_MADD_OP, `ALU_MADDU_OP, `ALU_MSUB_OP, `ALU_MSUBU_OP: begin
                    if (madd_msub_hilo_we == `WriteEnable) begin
                        {hi_o, lo_o} <= madd_msub_hilo_data;
                        hi_we_o <= `WriteEnable;
                        lo_we_o <= `WriteEnable;
                    end else if (cnt_i==2'b10) begin
                        hi_we_o <= `WriteDisable;
                        lo_we_o <= `WriteDisable;  
                    end
                end


                /*
                 * div、divu
                 * RLT: {Hi,Lo} <- rs/rt，Lo=商，Hi=余数
                */
                `ALU_DIV_OP, `ALU_DIVU_OP: begin
                    //更加严谨一些
                    if (div_hilo_we) begin
                        hi_we_o <= `WriteEnable;
                        lo_we_o <= `WriteEnable;
                        {hi_o, lo_o} <= div_result_i;
                    end else begin
                        hi_we_o <= `WriteDisable;
                        lo_we_o <= `WriteDisable;                     
                    end
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

    /*
     * 流水线暂停信号
    */
    always @(*) begin
        if (rst == `RstEnable) begin
            stallreq <= `NotStop;
        end else begin
            stallreq <= (stallreq_from_madd_msub || stallreq_from_div);
        end
    end
endmodule