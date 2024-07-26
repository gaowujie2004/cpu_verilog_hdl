`include "defines.v"

module div (
    input wire clk,
    input wire rst,

    input wire        signed_div_i,
    input wire [31:0] opdata1_i,
    input wire [31:0] opdata2_i,
    input wire        start_i,
    input wire        cancel_i,

    output reg [63:0] result_o,
    output reg        ready_o
);
    wire [32:0] sub_res;  //minuend-n的结果
    reg  [ 5:0] cnt;
    reg  [64:0] dividend;  //[63:32]被减数minuend(余数)、 [31:0]商
    reg  [ 1:0] state;
    reg  [31:0] divisor;  //被减数n
    reg  [31:0] temp_op1;  //被除数原码
    reg  [31:0] temp_op2;  //除数原码

    /*
     * divident(被除数)在DivFree被初始化
     * 注意：位宽是33位，最高位用来判断符号的
    */
    assign sub_res = {1'b0, dividend[63:32]} - {1'b0, divisor};

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            state <= `DivFree;
            ready_o <= `DivResultNotReady;
            result_o <= {`ZeroWord, `ZeroWord};
        end else begin
            case (state)
                `DivFree: begin
                    if (start_i == `DivStart && cancel_i == `False_v) begin
                        if (opdata2_i == `ZeroWord) begin
                            state <= `DivByZero;
                        end else begin
                            state <= `DivOn;
                            cnt   <= 6'b000000;

                            if (signed_div_i == 1'b1 && opdata1_i[31] == 1'b1) begin
                                temp_op1 = ~opdata1_i + 1;
                            end else begin
                                temp_op1 = opdata1_i;
                            end

                            if (signed_div_i == 1'b1 && opdata2_i[31] == 1'b1) begin
                                temp_op2 = ~opdata2_i + 1;
                            end else begin
                                temp_op2 = opdata2_i;
                            end

                            dividend <= {`ZeroWord, `ZeroWord};
                            dividend[32:1] <= temp_op1;
                            divisor <= temp_op2;
                        end
                    end else begin
                        ready_o  <= `DivResultNotReady;
                        result_o <= {`ZeroWord, `ZeroWord};
                    end
                end

                `DivByZero: begin
                    dividend <= {`ZeroWord, `ZeroWord};
                    state <= `DivEnd;
                end

                `DivOn: begin
                    if (cancel_i == `False_v) begin
                        if (cnt != 6'b100000) begin
                            if (sub_res[32] == 1'b1) begin
                                /*
                                 * dividend[63:0]是恢复余数. 整体效果：恢复余数,且余数与商同步左移1位,最低位是0
                                */
                                dividend <= {dividend[63:0], 1'b0};
                            end else begin
                                /* sub_res是33位，[31:0]很显然是左移一位，最高位丢失 */
                                /* 不是同步位移，各自左移一位 */
                                dividend <= {sub_res[31:0], dividend[31:0], 1'b1};
                            end
                            cnt <= cnt + 1;
                        end else begin
                            if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
                                dividend[31:0] <= (~dividend[31:0] + 1);
                            end
                            if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ dividend[64]) == 1'b1)) begin
                                dividend[64:33] <= (~dividend[64:33] + 1);
                            end
                            state <= `DivEnd;
                            cnt   <= 6'b000000;
                        end
                    end else begin
                        state <= `DivFree;
                    end
                end

                `DivEnd: begin
                    result_o <= {dividend[64:33], dividend[31:0]};
                    ready_o  <= `DivResultReady;
                    if (start_i == `DivStop) begin
                        state <= `DivFree;
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord, `ZeroWord};
                    end
                end
            endcase
        end
    end
endmodule
