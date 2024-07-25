`include "defines.v"
`define WB_IDLE 2'b00
`define WB_BUSY 2'b01
`define WB_WAIT_FOR_STALL 2'b01 //等待、暂停


/*
 * 有限状态机实现总线接口模块，一共3个状态。
 * 状态改变是存储器+组合逻辑+输入、状态输出是纯组合逻辑电路
*/
module wb_bus (
    input wire clk,
    input wire rst,
    /*CTRL*/
    input wire[5:0] stall_i,    //流水线暂停信号
    input wire      flush_i,    //流水线清除信号

    /*CPU*/
    input wire               cpu_ce_i,        //来自CPU的访问请求信号
    input wire[`InstAddrBus] cpu_addr_i,      //来自CPU的地址数据
    input wire[`RegBus]      cpu_data_i,      //来自CPU的数据
    input wire               cpu_we_i,        //来自CPU的写操作信号
    input wire[3:0]          cpu_sel_i,       //来自CPU的字节选择信号
    output reg[`RegBus]      cpu_data_o,      //从设备传送到CPU的数据
    output reg               stallreq,        //to CTRL

    /*Wishbone总线输出（CPU->从设备）*/
    output reg[`InstAddrBus] wishbone_addr_o,
    output reg[`RegBus]      wishbone_data_o,
    output reg               wishbone_we_o,
    output reg[3:0]          wishbone_sel_o,
    output reg               wishbone_stb_o,   //总线选通信号
    output reg               wishbone_cyc_o,   //总线周期信号
    /*Wishbone总线输入（从设备->CPU）*/
    input wire[`RegBus]       wishbone_data_i,       //从设备的数据
    input wire                wishbone_ack_i         //从设备是否响应（传送完毕？）
);
    reg[1:0]     wishbone_state;     //保存状态
    reg[`RegBus] read_data_buf;      //锁存从设备数据
    
    /*
     * 状态转换时序电路，时序电路必须是边沿敏感的
     * 输入：其他输入、现态
     * 输出：次态
    */
    always @ (posedge clk) begin
		if(rst == `RstEnable) begin
			wishbone_state <= `WB_IDLE;
			wishbone_addr_o <= `ZeroWord;
			wishbone_data_o <= `ZeroWord;
			wishbone_we_o <= `WriteDisable;
			wishbone_sel_o <= 4'b0000;
			wishbone_stb_o <= 1'b0;
			wishbone_cyc_o <= 1'b0;
			read_data_buf <= `ZeroWord;
		end else begin
			case (wishbone_state)
				`WB_IDLE: begin
					if((cpu_ce_i == 1'b1) && (flush_i == `False_v)) begin
						wishbone_state <= `WB_BUSY;
						wishbone_stb_o <= 1'b1;
						wishbone_cyc_o <= 1'b1;
						wishbone_addr_o <= cpu_addr_i;
						wishbone_data_o <= cpu_data_i;
						wishbone_we_o <= cpu_we_i;
						wishbone_sel_o <=  cpu_sel_i;
						read_data_buf <= `ZeroWord;	
					end							
				end

				`WB_BUSY: begin
					if(wishbone_ack_i == 1'b1) begin
						wishbone_state <= `WB_IDLE;
						wishbone_stb_o <= 1'b0;
						wishbone_cyc_o <= 1'b0;
						wishbone_addr_o <= `ZeroWord;
						wishbone_data_o <= `ZeroWord;
						wishbone_we_o <= `WriteDisable;
						wishbone_sel_o <=  4'b0000;
                        
						if(cpu_we_i == `WriteDisable) begin
							read_data_buf <= wishbone_data_i;
						end
						if(stall_i != 6'b000000) begin
							wishbone_state <= `WB_WAIT_FOR_STALL;
						end					
					end else if(flush_i == `True_v) begin
						wishbone_state <= `WB_IDLE;
					    wishbone_stb_o <= 1'b0;
						wishbone_cyc_o <= 1'b0;
						wishbone_addr_o <= `ZeroWord;
						wishbone_data_o <= `ZeroWord;
						wishbone_we_o <= `WriteDisable;
						wishbone_sel_o <=  4'b0000;
						read_data_buf <= `ZeroWord;
					end
				end

                // 此时的Wishbone总线访问已经结束
				`WB_WAIT_FOR_STALL: begin
					if(stall_i == 6'b000000) begin
						wishbone_state <= `WB_IDLE;
					end
				end
			endcase
		end
	end      
			

	always @ (*) begin
		if(rst == `RstEnable) begin
			stallreq <= `NotStop;
			cpu_data_o <= `ZeroWord;
		end else begin
			case (wishbone_state)
				`WB_IDLE:		begin
					if((cpu_ce_i == 1'b1) && (flush_i == `False_v)) begin
                        /*
                         * Why: 暂停原因是，进行设备读了，要暂停，等从设备有结果了再继续执行流水线
                         * Think: 解决了我很久的疑惑 “CPU读/写设备，设备的速度一般比较慢，那么这个等待的过程CPU是如何运行的？”
                         * 这里可以看到是暂停流水线了，就是暂停等待。
                         * 但是我感觉现代CPU应该不会傻傻地暂停流水线吧？应该会有其他解决策略？
                        */
						stallreq <= `Stop;
						cpu_data_o <= `ZeroWord;				
                    end else begin
                        stallreq <= `NotStop;
                    end
				end

				`WB_BUSY: begin
					if(wishbone_ack_i == 1'b1) begin
                        /*
                         * 从设备操作完成，数据已被CPU读取到，可取消流水线暂停了。
                        */
						stallreq <= `NotStop;
						if(wishbone_we_o == `WriteDisable) begin
						    cpu_data_o <= wishbone_data_i;
						end else begin
						    cpu_data_o <= `ZeroWord;
						end							
					end else begin
                        /*
                         * 从设备还在操作未完成，流水线继续暂停CPU等待从设备
                        */
						stallreq <= `Stop;	
						cpu_data_o <= `ZeroWord;				
					end
				end

                // 此时的Wishbone总线访问已经结束
				`WB_WAIT_FOR_STALL: begin
					stallreq <= `NotStop;
					cpu_data_o <= read_data_buf;
				end
			endcase
		end
	end

    
endmodule


