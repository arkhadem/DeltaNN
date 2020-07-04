`include "sys_defs.svh"

module Pool_array (
	input clock,
	input reset,
	
	input finish,
	input [(`OUT_BIN_LEN - 1) : 0] AF_outputs [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],
	input [1 : 0] Pool_type,
	input [2 : 0] Pool_stride,
	input [2 : 0] Pool_kernel_size,
	
	input SRAM_r_en,
    input [($clog2(`OUTPUT_HEIGHT) - 1) : 0] SRAM_r,
    input [($clog2(`OUTPUT_WIDTH) - 1) : 0] SRAM_c,
	output reg [((`BIN_LEN * `OUTPUT_SRAM_LEN) - 1) : 0] SRAM_out
);

    reg [(`OUT_BIN_LEN - 1) : 0] AF_outputs_pooled [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0];

	always@(*) begin
		if(finish) begin
			for (int i = 0; i < `OUTPUT_HEIGHT; i++) begin
				for (int j = 0; j < `OUTPUT_WIDTH; j++) begin
					// for each output
					case (Pool_type)
						`POOL_NONE: AF_outputs_pooled[i][j] = AF_outputs[i][j];
						`POOL_MAX: begin
							AF_outputs_pooled[i][j] = 0;
							for (int k_r = 0; k_r < Pool_kernel_size; k_r++) begin
								for (int k_c = 0; k_c < Pool_kernel_size; k_c++) begin
									if(AF_outputs_pooled[i][j] < AF_outputs[(i*Pool_stride)+k_r][(j*Pool_stride)+k_c]) begin
										AF_outputs_pooled[i][j] = AF_outputs[(i*Pool_stride)+k_r][(j*Pool_stride)+k_c];
									end else begin
										AF_outputs_pooled[i][j] = AF_outputs_pooled[i][j];
									end
								end
							end
						end
						default : AF_outputs_pooled[i][j] = {`OUT_BIN_LEN{1'bz}};
					endcase
				end
			end
		end else begin
			for (int i = 0; i < `OUTPUT_HEIGHT; i++) begin
				for (int j = 0; j < `OUTPUT_WIDTH; j++) begin
					AF_outputs_pooled[i][j] = {`OUT_BIN_LEN{1'bz}};
				end
			end
		end
	end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			SRAM_out = {(`BIN_LEN * `OUTPUT_SRAM_LEN){1'bz}};
		end else if (SRAM_r_en == 1'b1) begin
			for (int i = 0; i < `OUTPUT_SRAM_LEN; i++) begin
				SRAM_out[(i * `BIN_LEN) +: `BIN_LEN] = AF_outputs_pooled[SRAM_r][SRAM_c + i][(`BIN_LEN - 1) : 0];
			end
		end else begin
			SRAM_out = {(`BIN_LEN * `OUTPUT_SRAM_LEN){1'bz}};
		end
	end

endmodule