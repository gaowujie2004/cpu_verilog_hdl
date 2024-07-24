`include "defines.v"

// 对 OpenMIPS_MIN_SOPC 进行 test bench，输入激励信号和时钟信号
module openmips_min_sopc_tb();
    reg CLOCK50;    // initial 语句块，必须是 reg 类型才能赋值
    reg rst;    

    // 时钟信号：10ns翻转一次，时钟周期=20ns，时钟频率 50MHZ
    initial begin
        CLOCK50 = 1'b0;
        forever #10 begin
            // 10ns执行一次
            CLOCK50 = ~CLOCK50;
        end
    end

    initial begin
        rst = `RstEnable;
        #195 rst = `RstDisable;
        #10000 $stop;
    end

    //元件例化
    openmips_min_sopc openmips_min_sopc_0(
        .rst(rst),
        .clk(CLOCK50)
    );

endmodule