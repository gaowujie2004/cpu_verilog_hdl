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
    


    output reg          timer_int_o, //定时中断触发
    output reg[`RegBus] data_o,      //读取的值

    output reg[`RegBus] count_o,     //计数器的值，只读
    output reg[`RegBus] compare_o,   //与count_o对比的值，若相等则定时中断触发
    output reg[`RegBus] status_o,    //控制处理器的操作模式、中断使能以及诊断状态
    output reg[`RegBus] cause_o,     //主要记录最近⼀次异常发⽣的原因，也控制软件中断请求
    output reg[`RegBus] epc_o,       //中断返回地址
    output reg[`RegBus] config_o,    //处理器有关的各种配置和功能信息，只读
    output reg[`RegBus] prid_o       //CPU硬件信息，只读
);
    //先写
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            data_o    <= `ZeroWord;
            count_o   <= `ZeroWord;
            compare_o <= `ZeroWord;
            status_o  <= 32'h10_00_00_00;
            cause_o   <= `ZeroWord;
            epc_o     <= `ZeroWord;
            config_o  <= 32'b00000000000000001000000000000000;
            prid_o    <= 32'b00000000010011000000000100000010;
            timer_int_o <= `InterruptNotAssert;
        end else begin
            count_o <= count_o + 1;
            if (compare_o!=0 && compare_o==count_o) begin
                timer_int_o <= `InterruptAssert;
            end else begin
                /*
                 * 当Count寄存器中的计数值与Compare寄存器中的值⼀样时，会产⽣定时中断。
                 * 这个中断会⼀直保持，直到有数据被写⼊Compare寄存器。
                */
            end
            cause_o[15:10]  <= int_i; //Cause的第10～15bit保存外部中断声明

            if (wb_we_i == `WriteEnable) begin
                case (wb_waddr_i)
                    `CP0_REG_COUNT: begin
                        count_o   <= wb_wdata_i;
                    end
                    `CP0_REG_COMPARE: begin
                        compare_o   <= wb_wdata_i;
                        timer_int_o <= `InterruptNotAssert;
                    end
                    `CP0_REG_STATUS: begin
                        status_o  <= wb_wdata_i;
                    end
                    `CP0_REG_CAUSE: begin
                        //Cause寄存器只有IP[1:0]、IV、WP字段是可写的
                        cause_o[9:8] <= wb_wdata_i[9:8];
                        cause_o[23] <= wb_wdata_i[23];
                        cause_o[22] <= wb_wdata_i[22];
                    end
                    `CP0_REG_EPC: begin
                        epc_o     <= wb_wdata_i;
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
            end else if (wb_we_i==`True_v && wb_waddr_i==raddr_i) begin
                /*
                 * I1: mtc0 $3, $31  CP0[3] <- R[31] 写CP0[3]
                 * I2: nop
                 * I3: mfco $4, $3   R[4] <- CP0[3]  读CP0[3]
                */
                /*I1指令刚进入WB阶段时还不能写入寄存器，因要等到下一个时钟上升沿才能写入，过意就直接拿过来了。*/
                data_o <= wb_wdata_i;
            end else begin
                /* 无数据相关，正常读 */
                case (raddr_i)
                    `CP0_REG_COUNT: begin
                        data_o   <= count_o;
                    end
                    `CP0_REG_COMPARE: begin
                        data_o   <= compare_o;
                    end
                    `CP0_REG_STATUS: begin
                        data_o  <= status_o;
                    end
                    `CP0_REG_CAUSE: begin
                        data_o  <= cause_o;
                    end
                    `CP0_REG_EPC: begin
                        data_o  <= epc_o;
                    end
                    `CP0_REG_CONFIG: begin
                        data_o  <= config_o;
                    end
                    `CP0_REG_PrId: begin
                        data_o  <= prid_o;
                    end
                endcase
            end
        end
    end
    
endmodule