module pc_reg (
    input wire clk,
    input wire rst,

    output reg [5:0] pc,
    output reg [0:0]  ce
);

    always @(posedge clk) begin
        if (rst == 1'b1) begin
            ce <= 1'b0;     // RST复位时，指令存储器不使能
        end else begin
            ce <= 1'b1;     // RST无效时，指令存储器使能
        end
    end                     //语句块结束后，非阻塞赋值完成

    always @(posedge clk) begin
        if (ce == 1'b1) begin
            pc <= pc + 1'b1;
        end else begin
            pc <= 6'b0;
        end
    end

    // 上面两个 always 可以合okok并为一个。

endmodule