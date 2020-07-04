`include "sys_defs.svh"

module APE_adder(
    input [(`OUT_BIN_LEN - 1) : 0] MPE_vals [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],
    input [(`OUT_BIN_LEN - 1) : 0] APE_vals [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],

    input enable,

    output [(`OUT_BIN_LEN - 1) : 0] output_vals [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0]
);

	genvar i, j;

	for (i = 0; i < `OUTPUT_HEIGHT; i++) begin: HEIGHT_GENERATE
		for (j = 0; j < `OUTPUT_WIDTH; j++) begin: HEIGHT_GENERATE
			assign output_vals[i][j] = enable ? MPE_vals[i][j] + APE_vals[i][j] : `OUT_BIN_LEN'bz;
		end
	end

endmodule