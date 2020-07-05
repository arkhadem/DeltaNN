`include "sys_defs.svh"

module Input_buffer(
    input clock,

    input w_enable,

    input [((`BIN_LEN * `INPUT_SRAM_LEN) - 1) : 0] SRAM_in,
    input [($clog2(`INPUT_HEIGHT) - 1) : 0] SRAM_r,
    input [($clog2(`INPUT_WIDTH) - 1) : 0] SRAM_c,

    output [(`BIN_LEN - 1) : 0] r_val [(`INPUT_HEIGHT - 1) : 0][(`INPUT_WIDTH - 1) : 0]
);

	reg [(`BIN_LEN - 1) : 0] my_register [(`INPUT_HEIGHT - 1) : 0][(`INPUT_WIDTH - 1) : 0];
	genvar i, j;

	always@(posedge clock) begin
		if(w_enable) begin
			for(int c_itr = 0; c_itr < `INPUT_SRAM_LEN; c_itr++) begin
				my_register[SRAM_r][SRAM_c + c_itr] = SRAM_in[(c_itr * `BIN_LEN) +: `BIN_LEN];
			end
		end
	end

	assign r_val = my_register;

	// for (i = 0; i < `INPUT_HEIGHT; i++) begin: HEIGHT_GENERATE
	// 	for (j = 0; j < `INPUT_WIDTH; j++) begin: HEIGHT_GENERATE
	// 		assign r_val[i][j] = r_enable ? my_register[i][j] : `BIN_LEN'bz;
	// 	end
	// end
endmodule