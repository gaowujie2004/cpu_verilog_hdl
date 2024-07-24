`include "defines.v"

/*
 * Think: 存储器的逻辑中，需要关注是大小端吗？我觉得不需要，一会测试一下
 * 通常都是说机器字节序，所以应该是和CPU相关。而当前模块是DRAM。
*/
module data_ram (
    input wire               clk,
    input wire[`InstAddrBus] addr_i,  //内存地址
    input wire[`RegBus]      data_i,  //写入ram的数据
    input wire               we_i,    //是否写？
    input wire[`MemSelBus]   sel_i,   //字节选择，低位指明多字节数据LSB、高位指明多字节数据MSB
    input wire               ce_i,    //存储器使能控制

    output reg[`RegBus]     data_o    //读内存的数据
);
    /* 
     * 前面是存储单元位宽，本存储器是字节编址，故存储单元位宽8bit，
     * 本存储器数据字长=32bit，一次数据读在数据总线上传递32bit数据，存储单元共有 DataMemNum*4 个
     * 4个基本存储单元可并行读取，共32bit的数据
    */
    reg[`ByteWidth] ram0[0:`DataMemNum-1];  //大端字节序。该字节存储体存放多字节数据的最高有效位(MSB)1Byte，即addr_i[1:0]==0也是存储低地址数据，sel与该有映射关系
    reg[`ByteWidth] ram1[0:`DataMemNum-1];  
    reg[`ByteWidth] ram2[0:`DataMemNum-1]; 
    reg[`ByteWidth] ram3[0:`DataMemNum-1];  //大端字节序。该字节存储体存放多字节数据的最低有效位(LSB)1Byte，即addr_i[1:0]==3也是存储高地址数据。

    wire[`DataMemNumLog2-1:0] inner_addr = addr_i[`DataMemNumLog2+1:2];

    /* 写操作 */
    always @(posedge clk) begin
        if (ce_i==`ChipEnable && we_i==`WriteEnable) begin
            // ram0存储数据的最高有效位，MSB数据在寄存器是在高位
            if (sel_i[3]) begin
                ram0[inner_addr] <= data_i[31:24];
            end
            if (sel_i[2]) begin
                ram1[inner_addr] <= data_i[23:16];
            end
            if (sel_i[1]) begin
                ram2[inner_addr] <= data_i[15:8];
            end
            if (sel_i[0]) begin
                ram3[inner_addr] <= data_i[7:0];
            end
        end
    end

    /* 读操作 */
    always @(*) begin
        if (ce_i==`ChipEnable && we_i==`WriteDisable) begin
            // ram0存储数据的最高有效位==sel[3]，MSB数据写入寄存器的高位
            if (sel_i[3]) begin
                data_o[31:24] <= ram0[inner_addr];
            end
            if (sel_i[2]) begin
                data_o[23:16] <= ram1[inner_addr];
            end
            if (sel_i[1]) begin
                data_o[15:8] <= ram2[inner_addr];
            end
            if (sel_i[0]) begin
                data_o[7:0] <= ram3[inner_addr];
            end
        end else begin
            data_o <= `ZeroWord;
        end
    end
endmodule