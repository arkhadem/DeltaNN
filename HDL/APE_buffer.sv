`include "sys_defs.svh"

module APE_buffer(
    input clock,

    input w_enable,		// comes from scheduler

    input enable,

    input [(`OUT_BIN_LEN - 1) : 0] bias,

    input [(`OUT_BIN_LEN - 1) : 0] adder_outputs [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],

    output reg [(`OUT_BIN_LEN - 1) : 0] buffer_outputs [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0]
);

	always@(posedge clock) begin
		if(w_enable) begin
			for(int r_itr = 0; r_itr < `OUTPUT_HEIGHT; r_itr++) begin
				for(int c_itr = 0; c_itr < `OUTPUT_WIDTH; c_itr++) begin
					buffer_outputs[r_itr][c_itr] = bias;
				end
			end
		end else if(enable) begin
			for (int i = 0; i < `OUTPUT_HEIGHT; i++) begin: HEIGHT_GENERATE
				for (int j = 0; j < `OUTPUT_WIDTH; j++) begin: HEIGHT_GENERATE
					buffer_outputs[i][j] = adder_outputs[i][j];
				end
			end
		end
	end

endmodule