`include "sys_defs.svh"

module MPE(
    input clock,
    input reset,

    input enable,		// shows if we don't have stall

    input [(`BIN_LEN - 1) : 0] inputs [(`INPUT_HEIGHT - 1) : 0][(`INPUT_WIDTH - 1) : 0],

    input [(`BIN_LEN - 1) : 0] weight_val,
    input weight_abs,

	input [($clog2(`KERNEL_HEIGHT) - 1) : 0] weight_height, 
	input [($clog2(`KERNEL_WIDTH) - 1) : 0] weight_width,
	input [2 : 0] stride,

    output [(`OUT_BIN_LEN - 1) : 0] output_vals [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],
    output out_ready
);

	wire [(`BIN_LEN - 1) : 0] input_vals [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0];


	MPE_in2out MPE_in2out_inst(
		.in_vals(inputs),
		.out_vals(input_vals),
		.weight_height(weight_height), 
		.weight_width(weight_width),
		.stride(stride)
	);

	MPE_multiplier MPE_multiplier_inst(
		.clock      (clock),
		.reset      (reset),

	    .weight_val	(weight_val),
		.weight_abs	(weight_abs),

	    .input_vals	(input_vals),

	    .enable		(enable),

	    .output_vals(output_vals),
	    .out_ready	(out_ready)
	);

endmodule