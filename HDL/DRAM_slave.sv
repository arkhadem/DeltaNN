`include "sys_defs.svh"

module DRAM_slave (
	//DRAM Signals
	input clock,
	input reset,
	input ChipSelect,
	input Read,
	input Write,
	input [3:0] Address,
	output reg [31:0] ReadData,
	input [31:0] WriteData,

	//DeltaAcc Signals
	output start,											// 1 bit
	input ack,
	input done,												// 1 bit
    output [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] IC_Num,	// 10 bits
    output [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] OC_Num,	// 10 bits

    output [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] RC_Size,	// 8 bits
    output [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] ORC_Size,	// 8 bits
    output [3 : 0] kernel_size,
    output [2 : 0] stride,
    output [1 : 0] AF_type,
    output [1 : 0] Pool_type,
    output [2 : 0] Pool_stride,
    output [2 : 0] Pool_kernel_size,

    output [($clog2(`MAX_WEIGHT_DELTA_LEN) - 1) : 0] weight_delta_len,	// 2 bits
    output [($clog2(`MAX_WEIGHT_NUM_LEN) - 1) : 0] weight_num_len,		// 4 bits
    output [($clog2(`MAX_IDX_DELTA_LEN) - 1) : 0] idx_delta_len,		// 4 bits

    output load_input,
	output store_output,

	output [31 : 0] weight_start_address,
	output [31 : 0] weight_idx_start_offset,
	output [31 : 0] weight_unique_start_offset,
	output [31 : 0] weight_repetition_start_offset,
	output [31 : 0] bias_start_address,
	output [31 : 0] input_start_address,
	output [31 : 0] output_start_address
);

	reg [31:0] Registers [8:0];
	integer i;
	always@(*) begin
		if(ChipSelect == 1'b1) begin
			if(Read == 1'b1) begin
				ReadData <= Registers[Address];
			end
			else begin
				ReadData <= 32'bz;
			end
		end
		else begin
			ReadData <= 32'bz;
		end
	end
	always@(posedge clock) begin
		if(reset == 1'b1) begin
			for (i = 0; i < 5; i = i + 1)
				Registers[i] <= 32'b0;
		end
		else begin
			if(ack == 1'b1) begin
				Registers[0][0] = 1'b0;
			end
			if(done == 1'b1) begin
				Registers[0][31] = 1'b1;
			end
			if(ChipSelect == 1'b1) begin
				if(Write == 1'b1) begin
					Registers[Address] <= WriteData;
					Registers[0][31] = 1'b0;
				end
			end
		end
	end
	assign start = Registers[0][0];
	assign IC_Num = Registers[0][10:1];
	assign OC_Num = Registers[0][20:11];
	assign weight_delta_len = Registers[0][22:21];
	assign weight_num_len = Registers[0][25:23];
	assign idx_delta_len = Registers[0][28:26];
	assign load_input = Registers[0][29];
	assign store_output = Registers[0][30];

	assign RC_Size = Registers[1][7:0];
	assign ORC_Size = Registers[1][15:8];
	assign kernel_size = Registers[1][19:16];
	assign stride = Registers[1][22:20];
	assign AF_type = Registers[1][23:22];
	assign Pool_type = Registers[1][25:24];
	assign Pool_stride = Registers[1][28:26];
	assign Pool_kernel_size = Registers[1][31:29];

	assign weight_start_address = Registers[2];
	assign weight_idx_start_offset = Registers[3];
	assign weight_unique_start_offset = Registers[4];
	assign weight_repetition_start_offset = Registers[5];
	assign bias_start_address = Registers[6];
	assign input_start_address = Registers[7];
	assign output_start_address = Registers[8];
endmodule