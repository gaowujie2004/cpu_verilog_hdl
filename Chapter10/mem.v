`include "defines.v"

module mem (
    input wire rst,
    input wire[`InstBus]    inst_i,        //debuger

    input wire[`RegAddrBus] waddr_i,       //目标寄存器地址
    input wire              reg_we_i,      //目标寄存器写使能
    input wire[`RegBus]     alu_res_i,     //alu运算结果

    input wire             hi_we_i,       //Hi寄存器写使能
    input wire             lo_we_i,       //Lo寄存器写使能
    input wire[`RegBus]    hi_i,          //指令执行阶段对Hi写入的数据
    input wire[`RegBus]    lo_i,          //指令执行阶段对Lo写入的数据

    input wire[`AluOpBus]   aluop_i,
    input wire[`InstAddrBus]mem_addr_i,
    input wire[`RegBus]     reg2_data_i,  //写入RAM的数据
    input wire[`RegBus]     mem_data_i,   //读RAM的数据

    /*llbit*/
    input wire              llbit_i,

    //输入流水寄存器
    output reg[`RegAddrBus] waddr_o,     //目的寄存器地址
    output reg              reg_we_o,    //目的寄存器写使能
    output reg[`RegBus]     wdata_o,     //目的寄存器写入数据

    output reg             hi_we_o,       
    output reg             lo_we_o,       
    output reg[`RegBus]    hi_o,          
    output reg[`RegBus]    lo_o,

    /*输入RAM*/
    output reg[`InstAddrBus]mem_addr_o,
    output reg              mem_we_o,
    output reg[`MemSelBus]  mem_sel_o,   //字节选择，低位sel[0]是指明LSB、高位sel[3]是指明MSB
    output reg[`RegBus]     mem_data_o,  //向RAM输出的写入数据
    output reg              mem_ce_o,    //存储器使能控制

    /*llbit*/
    output reg llbit_we_o,
    output reg llbit_value_o,

    output reg[`InstBus]  inst_o         //debuger
);
    wire[1:0] addr_lowest_two_bit = mem_addr_i[1:0];
    always @(*) begin
        if (rst == `RstEnable) begin
            waddr_o <= `NOPRegAddr;
            reg_we_o <= `WriteDisable;
            wdata_o <= `ZeroWord;

            hi_we_o   <= `WriteDisable;
            lo_we_o   <= `WriteDisable;
            hi_o      <= `ZeroWord;
            lo_o      <= `ZeroWord;

            inst_o    <= `ZeroWord;

            mem_addr_o <= `ZeroWord;
            mem_we_o   <= `False_v;
            mem_sel_o  <= 4'b0000;
            mem_data_o <= `ZeroWord;
            mem_ce_o   <= `ChipDisable;

            llbit_we_o <= `WriteDisable;
            llbit_value_o <= 1'b0;
        end else begin
            waddr_o <= waddr_i;
            reg_we_o <= reg_we_i;
            wdata_o <= alu_res_i;

            hi_we_o   <= hi_we_i;
            lo_we_o   <= lo_we_i;
            hi_o      <= hi_i;
            lo_o      <= lo_i;

            inst_o    <= inst_i;

            /*
             * load、store指令
             * 不带u的，会进行符号扩展至32bit
             * 带u，零扩展至32bit
            */
            mem_addr_o <= mem_addr_i;
            mem_data_o <= `ZeroWord;
            mem_we_o   <= `WriteDisable;
            mem_sel_o  <= 4'b0000;
            mem_ce_o   <= `ChipDisable;
            llbit_we_o <= `WriteDisable;
            llbit_value_o <= 1'b0;
            /*
             * 大端字节序，低内存地址存放多字节数据的MSB。以下内存按字节编址。
             * 地址：0b00   0b01   0b10    0b11
             * 数据：0xa0   0xb0   0xc0    0xd0
             *       MSB
             * M[0]=0x(MSB)a0b0c0d0  
             * 字节序是描述多字节数据在内存中的存储顺序，与寄存器无关
             * 在寄存器中，高位部分reg1_data_i[31:24]永远都是存放多字节数据的MSB         
            */
            case (aluop_i)
                `ALU_LB_OP: begin               //不考虑地址对齐
                    mem_ce_o   <= `ChipEnable;
                    case (addr_lowest_two_bit)
                        2'b00: begin
                            /*
                             * 0、4、8这样的地址，这样的地址位于4Byte起始处，故这样的地址是最低地址，
                             * 内存最低地址它存放的是MSB（数据的最高有效位）。
                             * sel[3]=1，读内存低地址数据，即内存低位对应MSB。
                            */
                            mem_sel_o <= 4'b1000;
                            /*
                             * Think: addr_i[1:0]==0，且是大端字节序，故而说明当前地址取的数据是最高有效位的1Byte数据，可以带入0b00作为一个地址实验一下。
                             * wdata_o最终选择的内存数据进入下一个流水阶段，最终写回Regfile
                             * 扩展：将读出的1Byte数据按符号扩展到32位，再放入寄存器；可以看出读出的1Byte数据在寄存器的低8位。
                            */
                            wdata_o   <= {{24{mem_data_i[31]}}, mem_data_i[31:24]};
                        end
                        2'b01: begin
                            mem_sel_o <= 4'b0100;
                            wdata_o   <= {{24{mem_data_i[23]}}, mem_data_i[23:16]};
                        end
                        2'b10: begin
                            mem_sel_o <= 4'b0010;
                            wdata_o   <= {{24{mem_data_i[15]}}, mem_data_i[15:8]};
                        end

                        2'b11: begin
                            mem_sel_o <= 4'b0001;
                            wdata_o   <= {{24{mem_data_i[7]}}, mem_data_i[7:0]};
                        end          
                    endcase
                end 
                `ALU_LBU_OP: begin              //不考虑地址对齐
                    mem_ce_o   <= `ChipEnable;
                    case (addr_lowest_two_bit)
                        2'b00: begin
                            mem_sel_o <= 4'b1000;
                            wdata_o   <= {24'b0, mem_data_i[31:24]};
                        end
                        2'b01: begin
                            mem_sel_o <= 4'b0100;
                            wdata_o   <= {24'b0, mem_data_i[23:16]};
                        end
                        2'b10: begin
                            mem_sel_o <= 4'b0010;
                            wdata_o   <= {24'b0, mem_data_i[15:8]};
                        end
                        2'b11: begin
                            mem_sel_o <= 4'b0001;
                            wdata_o   <= {24'b0, mem_data_i[7:0]};
                        end      
                    endcase                 
                end
                `ALU_LH_OP: begin               //2Byte对齐
                    mem_ce_o   <= `ChipEnable;
                    case (addr_lowest_two_bit)
                        2'b00: begin
                            // sel[3]指明MSB
                            mem_sel_o <= 4'b1100;
                            /*
                             * Think: mem_addr_i[1:0]==00，且是大端字节序，故而说明当前地址取的数据是最高有效位的1Byte数据，可以带入0b00作为一个地址实验一下。
                             * wdata_o最终选择的内存数据进入下一个流水阶段
                             * LB：将读出的1Byte数据按符号扩展到32位，再放入寄存器。
                             * 可以看出读出的1Byte数据在寄存器的低8位。
                            */
                            wdata_o   <= {{16{mem_data_i[31]}}, mem_data_i[31:16]};
                        end
                        2'b10: begin
                            mem_sel_o <= 4'b0011;
                            wdata_o   <= {{16{mem_data_i[15]}}, mem_data_i[15:0]};
                        end
                        default: begin
                            // TODO: 未对齐时，为什么是清零？应该来个中断吧？
                            wdata_o   <= `ZeroWord;
                        end      
                    endcase 
                end
                `ALU_LHU_OP: begin              //2Byte对齐
                    mem_ce_o   <= `ChipEnable;
                    case (addr_lowest_two_bit)
                        2'b00: begin
                            // sel[3]指明MSB
                            mem_sel_o <= 4'b1100;
                            wdata_o   <= {16'b0, mem_data_i[31:16]};
                        end
                        2'b10: begin
                            mem_sel_o <= 4'b0011;
                            wdata_o   <= {16'b0, mem_data_i[15:0]};
                        end
                        default: begin
                            wdata_o   <= `ZeroWord; //Why: 为2Byte对齐，为什么是清零？应该来个中断吧？
                        end      
                    endcase
                end
                `ALU_LL_OP: begin               //TODO: 不要求4byte对齐了吗？
                    mem_ce_o    <= `ChipEnable;
                    mem_sel_o   <= 4'b1111;
                    wdata_o     <= mem_data_i;      
                    llbit_we_o    <= `WriteEnable;
                    llbit_value_o <= 1'b1;
                end 
                `ALU_LW_OP: begin               //4Byte对齐
                    mem_ce_o   <= `ChipEnable;
                    if (addr_lowest_two_bit == 2'b00) begin
                        mem_sel_o <= 4'b1111;
                        wdata_o   <= mem_data_i;
                    end else begin
                        wdata_o   <= `ZeroWord; // TODO: 为2Byte对齐，为什么是清零？应该来个中断吧？        
                    end
                end
                /*
                 * 目的寄存器的部分字节位，不会改变
                 * 从地址为loadaddr_align处加载⼀个字，然后将这个字的最低有效位(LSB)的4-n个字节保存到R[rt]的高位，
                 * 并且保持低n字节不变
                */
                `ALU_LWL_OP: begin
                    mem_ce_o   <= `ChipEnable;
                    mem_addr_o <= {mem_addr_i[31:2], 2'b00};  /* 4Byte对齐，相当于addr%4 */
                    mem_sel_o  <= 4'b1111;
                    
                    /* 4-n */
                    case (addr_lowest_two_bit)
                        //将加载到的字的最低有效位(LSB)4-0=4个字节数据，写入R[rt][31:0]
                        2'b00: begin
                            wdata_o  <= mem_data_i;
                        end

                        //将加载到的字的最低有效位(LSB)4-1=3个字节数据，写入R[rt]高3Byte，R[rt]低1Byte不变
                        2'b01: begin
                            wdata_o  <= {mem_data_i[23:0],  reg2_data_i[7:0]};
                        end

                        //将加载到的字的最低有效位(LSB)4-2=2个字节数据，写入R[rt]高2Byte，R[rt]低2Byte不变
                        2'b10: begin
                            wdata_o  <= {mem_data_i[15:0], reg2_data_i[15:0]};
                        end

                        //将加载到的字的最低有效位(LSB)4-3=1个字节数据，写入R[rt]高1Byte，R[rt]低3Byte不变
                        2'b11: begin
                            wdata_o  <= {mem_data_i[7:0],  reg2_data_i[23:0]};
                        end
                    endcase
                end
                /*
                 * 目的寄存器的部分字节位，不会改变
                 * 从地址为loadaddr_align处加载⼀个字，然后将这个字的最高有效位(MSB)的n+1个字节保存到R[rt]的低位，
                 * 并且保持高n字节不变
                */
                `ALU_LWR_OP: begin
                    mem_ce_o   <= `ChipEnable;
                    mem_addr_o <= {mem_addr_i[31:2], 2'b00};
                    mem_sel_o  <= 4'b1111;
                    
                    /* n+1 */
                    case (addr_lowest_two_bit)
                        //将加载到的字的最高有效位(MSB)0+1=1个字节数据，写入R[rt][7:0]，R[rt][31:8]保持不变
                        2'b00: begin
                            wdata_o  <= {reg2_data_i[31:8], mem_data_i[31:24]};
                        end

                        //将加载到的字的最高有效位(MSB)1+1=2个字节数据，写入R[rt][15:0]2Byte，R[rt][31:16]不变
                        2'b01: begin
                            wdata_o  <= {reg2_data_i[31:16], mem_data_i[31:16]};
                        end

                        //将加载到的字的最高有效位(MSB)2+1=3个字节数据，写入R[rt][23:0]3Byte，R[rt][31:24]不变
                        2'b10: begin
                            wdata_o  <= {reg2_data_i[31:24], mem_data_i[31:8]};
                        end

                        //将加载到的字的最高有效位(MSB)3+1=4个字节数据，写入R[rt]
                        2'b11: begin
                            wdata_o  <= mem_data_i;
                        end
                    endcase
                end

                
                /*
                 * Mem <- R[rt][sel]，等效于Mem<-reg2_data_i[sel]
                 * 选择reg2_data_i部分字节写入Mem
                */
                `ALU_SB_OP: begin
                    //reg2_data_i低8位写入
                    mem_ce_o   <= `ChipEnable;
                    mem_we_o   <= `WriteEnable;
                    mem_data_o <= {{reg2_data_i[7:0]}, {reg2_data_i[7:0]}, {reg2_data_i[7:0]}, {reg2_data_i[7:0]}};
                    case (addr_lowest_two_bit)
                        2'b00: begin
                            mem_sel_o  <= 4'b1000;
                        end
                        2'b01: begin
                            mem_sel_o  <= 4'b0100;
                        end
                        2'b10: begin
                            mem_sel_o  <= 4'b0010;
                        end
                        2'b11: begin
                            mem_sel_o  <= 4'b0001;
                        end
                    endcase
                end
                `ALU_SC_OP: begin              //TODO: 不4byte对齐了吗？
                    if (llbit_i == 1'b1) begin //RMW正常
                        //RAM Write
                        mem_ce_o   <= `ChipEnable;
                        mem_we_o   <= `WriteEnable;
                        mem_sel_o  <= 4'b1111;
                        mem_data_o <= reg2_data_i;
                        //R[rt] write
                        wdata_o    <= {31'b0, 1'b1};
                        //llbit
                        llbit_we_o    <= `WriteEnable;
                        llbit_value_o <= 1'b0;
                    end else begin
                        wdata_o    <= 32'b0;
                    end
                end
                `ALU_SH_OP: begin       //two byte align
                    //reg2_data_i低16位写入
                    mem_ce_o   <= `ChipEnable;
                    mem_we_o   <= `WriteEnable;
                    mem_data_o <= {reg2_data_i[15:0], reg2_data_i[15:0]};
                    case (addr_lowest_two_bit)
                        2'b00: begin
                            mem_sel_o  <= 4'b1100;
                        end
                        2'b10: begin
                            mem_sel_o  <= 4'b0011;
                        end
                    endcase
                end
                `ALU_SW_OP: begin
                    //reg2_data_i直接写入
                    mem_ce_o   <= `ChipEnable;
                    mem_we_o   <= `WriteEnable;
                    mem_data_o <= reg2_data_i;
                    case (addr_lowest_two_bit)
                        2'b00: begin
                            mem_sel_o  <= 4'b1111;
                        end
                    endcase
                end

                /*
                 * L是指从R[rt]寄存器的高位开始
                 * 从reg2_data_i选择部分字节数据写入
                */
                `ALU_SWL_OP: begin                  //可不对齐
                    mem_ce_o   <= `ChipEnable;
                    mem_we_o   <= `WriteEnable;
                    mem_addr_o <= {mem_addr_i[31:2], 2'b00}; //不对齐也可以
                    case (addr_lowest_two_bit)
                        /*将R[rt]最⾼4-0=4个字节存储到地址storeaddr处*/
                        2'b00: begin
                            mem_sel_o  <= 4'b1111;
                            mem_data_o <= reg2_data_i;
                        end

                        /*
                         * 源：R[rt]最⾼4-1=3个字节、目的首地址：storeaddr
                         * 具体的sel，得看addr_i[1:0]位
                        */
                        2'b01: begin
                            mem_sel_o  <= 4'b0111; 
                            mem_data_o <= {8'b0, reg2_data_i[31:8]};
                        end

                        /*
                         * 源：R[rt]最⾼4-2=2个字节、目的首地址：storeaddr
                         * 具体的sel，得看addr_i[1:0]位
                        */
                        2'b10: begin
                            mem_sel_o  <= 4'b0011;
                            mem_data_o <= {16'b0, reg2_data_i[31:16]};
                        end

                        /*
                         * 源：R[rt]最⾼4-3=1个字节、目的首地址：storeaddr
                         * 具体的sel，得看addr_i[1:0]位。 地址低2位=0b11，说明是高地址，那就是存数据的LSB
                        */
                        2'b11: begin
                            mem_sel_o  <= 4'b0001;
                            mem_data_o <= {24'b0, reg2_data_i[31:24]};
                        end
                    endcase
                end
                /*
                 * R是指从R[rt]寄存器的低位开始
                 * 从reg2_data_i选择部分字节数据写入
                */
                `ALU_SWR_OP: begin
                    mem_ce_o   <= `ChipEnable;
                    mem_we_o   <= `WriteEnable;
                    mem_addr_o <= {mem_addr_i[31:2], 2'b00};
                    case (addr_lowest_two_bit)
                        /*
                         * 源：R[rt]最低0+1=1个字节、目标首地址：storeaddr_align
                         * addr_i[1:0]=0，写入内存最低地址（MSB）
                        */
                        2'b00: begin
                            mem_sel_o  <= 4'b1000;
                            /*mem_data排列也很有讲究，在左侧是寄存器高位对应数据MSB，且与sel中的1的位置按顺序对应*/
                            mem_data_o <= {reg2_data_i[7:0], 24'b0};    
                        end

                        /*
                         * 源：R[rt]最低1+1=2个字节、目标首地址：storeaddr_align
                         * addr_i[1:0]=1，写入内存次高位地址
                        */
                        2'b01: begin
                            mem_sel_o  <= 4'b1100;
                            mem_data_o <= {reg2_data_i[15:0], 16'b0};
                        end

                        /*
                         * 源：R[rt]最低2+1=3个字节、目标首地址：storeaddr_align
                         * 具体的sel，依赖addr_i[1:0]位
                        */
                        2'b10: begin
                            mem_sel_o  <= 4'b1110;
                            mem_data_o <= {reg2_data_i[23:0], 8'b0};
                        end

                        /*
                         * 源：R[rt]最低3+1=4个字节、目标首地址：storeaddr_align
                        */
                        2'b11: begin
                            mem_sel_o  <= 4'b1111;
                            mem_data_o <= reg2_data_i;
                        end
                    endcase
                end
            endcase

        end
    end
endmodule