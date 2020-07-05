`include "sys_defs.svh"

module MPE_in2out(
	input [(`BIN_LEN - 1) : 0] in_vals [(`INPUT_HEIGHT - 1) : 0][(`INPUT_WIDTH - 1) : 0],
	input [(`BIN_LEN - 1) : 0] out_vals [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],
	input [($clog2(`KERNEL_HEIGHT) - 1) : 0] weight_height, 
	input [($clog2(`KERNEL_WIDTH) - 1) : 0] weight_width,
	input [2 : 0] stride

);

	genvar i, j;

	for (i = 0; i < `OUTPUT_HEIGHT; i++) begin: HEIGHT_GENERATE
		for (j = 0; j < `OUTPUT_WIDTH; j++) begin: HEIGHT_GENERATE
			assign out_vals[i][j] = in_vals[i + stride][j + weight_width]; // in_vals[i * stride + weight_height][j * stride + weight_width];
		end
	end

endmodule
