module test1 (
    input wire clk,
    input wire rst,
    input wire type,
    input wire [31:0] in1,
    input wire [31:0] in2,
    output reg [31:0] out
);

    always @(*) begin
        if (rst == 1'b1) begin
            out <= 32'b0;
        end else begin
            out <= in1 + in2;
        end
    end
    
endmodule



module test2 (
    input wire clk,
    input wire [31:0] in1,
    input wire [31:0] in2,
    output reg [31:0] out
);

    initial begin

endmodule




module test3 (
    input wire [7:1] vote,
    output reg pass
);

    reg[2:0] sum;
    integer i;

    // 过程语句，vote改变将触发执行
    always @(vote) begin
        sum = 0;
        i = 1;   // 过程赋值，阻塞赋值
        for (; i<=7; i=i+1) begin
            if (vote[i] == 1'b1) begin
                sum = sum + 1;
            end

            if (sum[2] == 1'b1) begin 
                pass = 1'b1;
            end else begin
                pass = 1'b0;
            end
        end
    end

endmodule

`include "defines.v"


module test4 (
    input wire [31:0] in1,
    input wire [31:0] in2,
    output wire [31:0] out
);

    assign out = in1 + in2;
    
endmodule