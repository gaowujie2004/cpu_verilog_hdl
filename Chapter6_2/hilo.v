module hilo (
    wire rst,
    input wire clk,

    input wire          wb_hi_we_i,     //Wb阶段
    input wire          wb_lo_we_i,     //WB阶段
    input wire[`RegBus] wb_hi_i,        //WB阶段，写入hi寄存器的数据
    input wire[`RegBus] wb_lo_i,        //WB阶段，写入lo寄存器的数据

    input wire          mem_hi_we_i,    //MEM阶段
    input wire          mem_lo_we_i,    //MEM阶段
    input wire[`RegBus] mem_hi_i,       //MEM阶段，写入hi寄存器的数据
    input wire[`RegBus] mem_lo_i,       //MEM阶段，写入lo寄存器的数据

    output reg[`RegBus] hi_o,           //读出hi寄存器的数据
    output reg[`RegBus] lo_o            //读出lo寄存器的数据
);
    reg[`RegBus] hi;
    reg[`RegBus] lo;

    // 写
    always @(posedge clk) begin
        if (rst == `RstEnable) begin 
            hi <= `ZeroWord; 
            lo <= `ZeroWord; 
        end else begin 
            if (wb_hi_we_i == `WriteEnable) begin
                hi <= wb_hi_i; 
            end 
            
            if (wb_lo_we_i == `WriteEnable) begin
                lo <= wb_lo_i;
            end
        end
    end

    /*
        Hi数据相关：前面指令向hi写入，但还没完成，此时又要读
        解决：数据转发（数据前推）
    */
    always @(*) begin
        if (rst == `RstEnable) begin
            lo_o <= `ZeroWord;
        end else begin
            /*
                转发优先级：
                mthi $0
                mthi $1
                mthi $2
                mfhi $4
                第4条指令读Hi，第1~3条指令写Hi，那肯定是读第3条指令的写入数据，所以应该先转发MEM、后WB
                因为：第4条指令在EX阶段，第3条指令在MEM阶段，第2条指令在WB阶段；第1条指令结束，已经写入Hi
            */
            if (mem_hi_we_i==`WriteEnable) begin
                /*
                mthi $1         Hi    <- R[$1]   写Hi
                mfhi $4         R[$4] <- Hi      读Hi
                问题：当最后一条指令在 EX 阶段时，第一条指令在 MEM 阶段
                解决（数据转发）：将第一条指令的写入Hi的数据，作为输出
                */
                hi_o <= mem_hi_i;
            end else if (wb_hi_we_i == `WriteEnable) begin
                /*
                mthi $1         Hi    <- R[$1]   写Hi
                nop
                mfhi $4         R[$4] <- Hi      读Hi
                问题：当最后一条指令在执行阶段时，nop在访存阶段，写Hi在写会阶段，但要等写回阶段结束后下一个时钟上升才能写入
                解决（数据转发）：先输出，随后上升沿一到再写入内部的 hi 寄存器。
                */
                hi_o <= wb_hi_i;
            end else begin
                /*
                mthi $1         Hi    <- R[$1]   写Hi
                nop
                nop
                mfhi $4         R[$4] <- Hi      读Hi
                说明：无数据相关问题，前面指令（第一条指令）对hi的写已经完成了
                */
                hi_o <= hi;
            end
        end
    end

    /*
        Lo数据相关：前面指令向lo写入，但还没完成，此时又要读
    */
    always @(*) begin
        if (rst == `RstEnable) begin
            lo_o <= `ZeroWord;
        end else begin
            if (mem_lo_we_i==`WriteEnable) begin
                //和hi一样
                lo_o <= mem_lo_i;
            end else if (wb_lo_we_i == `WriteEnable) begin
                //和hi一样
                lo_o <= wb_lo_i;
            end else begin
                //和hi一样
                lo_o <= lo;
            end
        end
    end


endmodule