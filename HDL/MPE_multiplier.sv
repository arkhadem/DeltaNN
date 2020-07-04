`include "sys_defs.svh"

module MPE_multiplier(
	input clock,
	input reset,

    input [(`BIN_LEN - 1) : 0] weight_val,
    input weight_abs,

    input [(`BIN_LEN - 1) : 0] input_vals [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],

    input enable,

    output reg [(`OUT_BIN_LEN - 1) : 0] output_vals [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],
    output out_ready
);

	genvar i, j;

	reg [(`BIN_LEN - 1) : 0] my_weight;
	reg [(`OUT_BIN_LEN - 1) : 0] my_inputs [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0];

	assign out_ready = (my_weight == 0) ? 1'b1 : 1'b0;

	always@(posedge clock) begin
		if(reset) begin
			my_weight = 0;
			for (int i = 0; i < `OUTPUT_HEIGHT; i++) begin
				for (int j = 0; j < `OUTPUT_WIDTH; j++) begin
					output_vals[i][j] = 0;
				end
			end
		end else if(enable) begin
			if(my_weight == 0) begin
				for (int i = 0; i < `OUTPUT_HEIGHT; i++) begin
					for (int j = 0; j < `OUTPUT_WIDTH; j++) begin
						my_inputs[i][j][(`OUT_BIN_LEN - 1) : `BIN_LEN] = 0;
						my_inputs[i][j][(`BIN_LEN - 1) : 0] = input_vals[i][j];
						if(weight_abs == 1'b1) begin
							output_vals[i][j] = 0;
						end
					end
				end
				my_weight = weight_val;
			end else begin
				for (int i = 0; i < `OUTPUT_HEIGHT; i++) begin
					for (int j = 0; j < `OUTPUT_WIDTH; j++) begin
						if(my_weight[0] == 1) begin
							output_vals[i][j] = output_vals[i][j] + my_inputs[i][j];
						end
						my_inputs[i][j] = my_inputs[i][j] << 1;
					end
				end
				my_weight = my_weight >> 1;
			end
		end
	end

endmodule