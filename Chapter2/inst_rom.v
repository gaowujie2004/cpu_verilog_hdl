module inst_rom (
    input wire       ce,
    input wire [5:0] addr,
    output reg [31:0] inst      // Why: 为什么是reg类型，wire可以吗？
);
    // BUG: rom[0:63] 这里写错了，导致数据是x
    // reg[31:0] rom[0:63];        // 二维存储器，共64个存储单元，每个存储单元占32bit
    reg[31:0] rom[63:0];
    initial begin
        $readmemh("C:\\Users\\Administrator\\Desktop\\verilog_hdl\\Chapter2\\rom.data", rom);
    end

    always @(*) begin
        if (ce == 1'b1) begin 
            inst <= rom[addr];
        end else begin
            inst <= 32'b0;
        end    
    end


endmodule