module inst_fetch_tb;

    reg CLOCK;
    reg rst;
    wire[31:0] inst;

    initial begin
        CLOCK = 1'b0;
        forever #10 begin
            CLOCK = ~CLOCK;
        end
    end

    initial begin
        rst = 1'b1;

        #195 rst = 1'b0;
        #1000 $stop;
    end

    inst_fetch inst_fetch_0(
        .rst(rst),
        .clk(CLOCK),
        .inst_o(inst)
    );

endmodule