`include "defines.v"

module cp0_reg (
    input wire clk,
    input wire rst,
    input wire          wb_we_i,
    input wire[4:0]     wb_waddr_i,
    input wire[`RegBus] wb_wdata_i,
    /*mem阶段*/
    input wire          mem_we_i,   
    input wire[4:0]     mem_waddr_i,   
    input wire[`RegBus] mem_wdata_i,

    input wire[5:0]     int_i,   //6个外部硬件中断源
    input wire[4:0]     raddr_i, //读CP0寄存器的地址
    /*异常相关*/
    input wire[`ExceptionTypeBus]    exception_type_i,      //最终的异常类型，mem阶段定义
    input wire                       is_in_delayslot_i,     //MEM阶段的指令是否为延迟槽指令
    input wire[`InstAddrBus]         inst_addr_i,           //当前阶段的指令的地址
    

    output reg          timer_int_o, //定时中断触发
    output reg[`RegBus] data_o,      //读取的值
    output reg[`RegBus] status_o,    //控制处理器的操作模式、中断使能以及诊断状态
    output reg[`RegBus] cause_o      //主要记录最近⼀次异常发⽣的原因，也控制软件中断请求
);
    reg[`RegBus] inner_count;     //计数器的值，只读
    reg[`RegBus] inner_compare;   //与count_o对比的值，若相等则定时中断触发
    reg[`RegBus] inner_status;    //控制处理器的操作模式、中断使能以及诊断状态
    reg[`RegBus] inner_cause;     //主要记录最近⼀次异常发⽣的原因，也控制软件中断请求
    reg[`RegBus] inner_epc;       //中断返回地址
    reg[`RegBus] inner_config;    //处理器有关的各种配置和功能信息，只读
    reg[`RegBus] inner_prid;      //CPU硬件信息，只读

    //先写
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            data_o    <= `ZeroWord;
            inner_count   <= `ZeroWord;
            inner_compare <= `ZeroWord;
            inner_status  <= 32'h10_00_00_00;
            inner_cause   <= `ZeroWord;
            inner_epc     <= `ZeroWord;
            inner_config  <= 32'b00000000000000001000000000000000;
            inner_prid    <= 32'b00000000010011000000000100000010;
            timer_int_o <= `InterruptNotAssert;
        end else begin
            inner_count <= inner_count + 1;
            if (inner_compare!=0 && inner_compare==inner_count) begin
                timer_int_o <= `InterruptAssert;
            end else begin
                /*
                 * 当Count寄存器中的计数值与Compare寄存器中的值⼀样时，会产⽣定时中断。
                 * 这个中断会⼀直保持，直到有数据被写⼊Compare寄存器。
                */
            end
            inner_cause[15:10]  <= int_i; //Cause的第10～15bit保存外部中断声明

            if (wb_we_i == `WriteEnable) begin
                case (wb_waddr_i)
                    `CP0_REG_COUNT: begin
                        inner_count   <= wb_wdata_i;
                    end
                    `CP0_REG_COMPARE: begin
                        inner_compare   <= wb_wdata_i;
                        timer_int_o <= `InterruptNotAssert;
                    end
                    `CP0_REG_STATUS: begin
                        inner_status  <= wb_wdata_i;
                    end
                    `CP0_REG_CAUSE: begin
                        //Cause寄存器只有IP[1:0]、IV、WP字段是可写的
                        inner_cause[9:8] <= wb_wdata_i[9:8];
                        inner_cause[23] <= wb_wdata_i[23];
                        inner_cause[22] <= wb_wdata_i[22];
                    end
                    `CP0_REG_EPC: begin
                        inner_epc     <= wb_wdata_i;
                    end
                endcase
            end
        end
    end

    //后读
    always @(*) begin
        if (rst == `RstEnable) begin
            data_o <= `ZeroWord;
            timer_int_o <= `InterruptNotAssert;
        end else begin
            /*
             * 数据前推，和Regfile、HiLo一样的思路；和HiLo是一模一样。
             * 优先级，也是一样的。
            */
            if (mem_we_i==`True_v && mem_waddr_i==raddr_i) begin
                data_o <= mem_wdata_i;
                if (raddr_i == `CP0_REG_STATUS) begin
                    status_o <= mem_wdata_i;
                end else if (raddr_i == `CP0_REG_CAUSE) begin
                    cause_o  <= mem_wdata_i;
                end
            end else if (wb_we_i==`True_v && wb_waddr_i==raddr_i) begin
                /*
                 * I1: mtc0 $3, $31  CP0[3] <- R[31] 写CP0[3]
                 * I2: nop
                 * I3: mfco $4, $3   R[4] <- CP0[3]  读CP0[3]
                */
                /*I1指令刚进入WB阶段时还不能写入寄存器，因要等到下一个时钟上升沿才能写入，过意就直接拿过来了。*/
                data_o <= wb_wdata_i;
                if (raddr_i == `CP0_REG_STATUS) begin
                    status_o <= wb_wdata_i;
                end else if (raddr_i == `CP0_REG_CAUSE) begin
                    cause_o  <= wb_wdata_i;
                end
            end else begin
                /* 无数据相关，正常读 */
                case (raddr_i)
                    `CP0_REG_COUNT: begin
                        data_o   <= inner_count;
                    end
                    `CP0_REG_COMPARE: begin
                        data_o   <= inner_compare;
                    end
                    `CP0_REG_STATUS: begin
                        data_o   <= inner_status;
                        status_o <= inner_status;
                    end
                    `CP0_REG_CAUSE: begin
                        data_o  <= inner_cause;
                        cause_o <= inner_cause;
                    end
                    `CP0_REG_EPC: begin
                        data_o  <= inner_epc;
                    end
                    `CP0_REG_CONFIG: begin
                        data_o  <= inner_config;
                    end
                    `CP0_REG_PrId: begin
                        data_o  <= inner_prid;
                    end
                endcase
            end
        end
    end

    always @(*) begin
        if (rst == `RstDisable) begin
            case (exception_type_i)
                `Exc_Interrupt: begin
                    if (is_in_delayslot_i) begin
                        inner_epc       <= inst_addr_i - 4;   //为什么呢？书中将的很清楚
                        inner_cause[31] <= `True_v;           //是否是延迟槽指令
                    end else begin
                        inner_epc       <= inst_addr_i;
                        inner_cause[31] <= `False_v;        
                    end
                    inner_cause[6:2] <= `ExcCode_Int;   //ExcCode field
                    inner_status[1]  <= 1'b1;           //Exc field是否异常
                end

                `Exc_Syscall: begin
                    if (inner_status[1] == 1'b0) begin
                        if (is_in_delayslot_i) begin
                            inner_epc       <= inst_addr_i - 4;
                            inner_cause[31] <= `True_v;
                        end else begin
                            inner_epc       <= inst_addr_i;
                            inner_cause[31] <= `False_v;        
                        end
                    end
                    inner_cause[6:2] <= `ExcCode_Syscall;
                    inner_status[1]  <= 1'b1;             
                end

                `Exc_InvalidInst: begin
                    if (inner_status[1] == 1'b0) begin
                        if (is_in_delayslot_i) begin
                            inner_epc       <= inst_addr_i - 4;
                            inner_cause[31] <= `True_v;
                        end else begin
                            inner_epc       <= inst_addr_i;
                            inner_cause[31] <= `False_v;        
                        end
                    end
                    inner_cause[6:2] <= `ExcCode_InvalidInst;
                    inner_status[1]  <= 1'b1;
                end

                `Exc_Trap: begin
                    if (inner_status[1] == 1'b0) begin
                        if (is_in_delayslot_i) begin
                            inner_epc       <= inst_addr_i - 4;
                            inner_cause[31] <= `True_v;
                        end else begin
                            inner_epc       <= inst_addr_i;
                            inner_cause[31] <= `False_v;        
                        end
                    end
                    inner_cause[6:2] <= `ExcCode_Trap;
                    inner_status[1]  <= 1'b1;
                end

                `Exc_Overflow: begin
                    if (inner_status[1] == 1'b0) begin
                        if (is_in_delayslot_i) begin
                            inner_epc       <= inst_addr_i - 4;
                            inner_cause[31] <= `True_v;
                        end else begin
                            inner_epc       <= inst_addr_i;
                            inner_cause[31] <= `False_v;        
                        end
                    end
                    inner_cause[6:2] <= `ExcCode_Overflow;
                    inner_status[1]  <= 1'b1;
                end

                `Exc_Eret: begin
                    inner_status[1]   <=  1'b0;
                end
            endcase
        end
    end
    
endmodule