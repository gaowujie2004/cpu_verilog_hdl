`include "defines.v"
`define WB_IDLE           3'b000
`define WB_BUSY_START     3'b001 //操作开始
`define WB_BUSY_PENDING   3'b010 //操作进行中
`define WB_BUSY_END       3'b011 //操作完成
`define WB_WAIT_FOR_STALL 3'b100 //操作完成，但有其他原因导致流水线暂停，需要将总线读取数据锁存



/*
 * Moore型电路，输出仅仅由状态（现态）决定，无需输入信号
*/
module wishbone_bus2 (
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
    reg[2:0]     wishbone_state;     //保存状态
    reg[`RegBus] read_data_buf;      //锁存从设备数据
    
    /*
     * 状态转换时序电路，时序电路必须是边沿敏感的
     * 输入：其他输入、现态
     * 输出：次态
    */
    always @ (posedge clk) begin
		if(rst == `RstEnable) begin
			wishbone_state <= `WB_IDLE;
			read_data_buf  <= `ZeroWord;
		end else begin
			case (wishbone_state)
				`WB_IDLE: begin
					if (cpu_ce_i==`ChipEnable && flush_i!=`True_v) begin
						wishbone_state <= `WB_BUSY_START;
					end else begin
						//继续保存该状态
						read_data_buf  <= `ZeroWord;
						wishbone_state <= `WB_IDLE;
					end
				end

				`WB_BUSY_START: begin
					if (flush_i == `True_v) begin
						wishbone_state <= `WB_IDLE;
					end else begin
						// 即便流水线暂停，也不影响总线读。因为流水线暂停结束后还是需要总线数据的
						wishbone_state <= `WB_BUSY_PENDING;
					end
				end

				`WB_BUSY_PENDING: begin
					if (flush_i == `True_v) begin
						wishbone_state <= `WB_IDLE;
					end else if (wishbone_ack_i == `True_v) begin //总线操作完成
						if (stall_i == 6'b000_000) begin
							//有其他的流水线暂停
							wishbone_state <= `WB_WAIT_FOR_STALL;
						end else begin
							wishbone_state <= `WB_BUSY_END;
						end

						if (cpu_we_i == `WriteDisable) begin
							read_data_buf  <= wishbone_data_i;
						end
					end else begin
						// 继续保持该状态
						wishbone_state <= `WB_BUSY_PENDING;
					end
				end

				`WB_BUSY_END: begin
					wishbone_state  <= `WB_IDLE;
				end

				`WB_WAIT_FOR_STALL: begin
					if (stall_i==6'b000_000 || flush_i==`True_v) begin
						wishbone_state  <= `WB_IDLE;
					end else begin
						// 继续保存该状态
						wishbone_state <= `WB_WAIT_FOR_STALL;
					end
				end
			endcase
		end
	end      
			

	always @ (*) begin
		case (wishbone_state)
			`WB_IDLE: begin
				wishbone_stb_o  <= 1'b0;
				wishbone_cyc_o  <= 1'b0;
				wishbone_addr_o <= `ZeroWord;
				wishbone_data_o <= `ZeroWord;
				wishbone_we_o   <= `WriteDisable;
				wishbone_sel_o  <= 4'b0000;
				cpu_data_o      <= `ZeroWord;
				stallreq        <= `NotStop;
			end

			`WB_BUSY_START, `WB_BUSY_PENDING: begin
				wishbone_stb_o   <= 1'b1;
				wishbone_cyc_o   <= 1'b1;
				wishbone_addr_o  <= cpu_addr_i;
				wishbone_data_o  <= cpu_data_i;
				wishbone_we_o    <= cpu_we_i;
				wishbone_sel_o   <=  cpu_sel_i;

				cpu_data_o       <= `ZeroWord;
				stallreq         <= `Stop;
			end

			`WB_BUSY_END, `WB_WAIT_FOR_STALL: begin
				wishbone_stb_o   <= 1'b0;
				wishbone_cyc_o   <= 1'b0;
				wishbone_addr_o  <= `ZeroWord;
				wishbone_data_o  <= `ZeroWord;
				wishbone_we_o    <= `WriteDisable;
				wishbone_sel_o   <=  4'b0000;
				cpu_data_o       <= read_data_buf;
				stallreq         <= `NotStop;
			end
		endcase
	end

    
endmodule


