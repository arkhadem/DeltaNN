`include "sys_defs.svh"

module APE(
    input clock,
    input reset,

	input enable,		// shows if we don't have stall
	input finish,		// shows if indices are finished

	input [1 : 0] AF_type,
	input [1 : 0] Pool_type,
	input [2 : 0] Pool_stride,
	input [2 : 0] Pool_kernel_size,

	// SRAM ports comes from scheduler directly
    // For writing bias
    input [(`OUT_BIN_LEN - 1) : 0] bias,
    input w_enable,
    input r_enable,
    // For reading output data
    output [((`BIN_LEN * `OUTPUT_SRAM_LEN) - 1) : 0] SRAM_out,
    input [($clog2(`OUTPUT_HEIGHT) - 1) : 0] SRAM_r_out,
    input [($clog2(`OUTPUT_WIDTH) - 1) : 0] SRAM_c_out,

    input [(`OUT_BIN_LEN - 1) : 0] MPE_vals [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0]		// multiplied values comming from MPEs
);

	wire [(`OUT_BIN_LEN - 1) : 0] buffer_outputs [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0];
	wire [(`OUT_BIN_LEN - 1) : 0] AF_outputs [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0];
    wire [(`OUT_BIN_LEN - 1) : 0] adder_outputs [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0];

	APE_buffer APE_buffer_inst (
	    .clock(clock),

	    .w_enable(w_enable),

	    .enable(enable),

	    .bias(bias),

	    .adder_outputs(adder_outputs),

	    .buffer_outputs(buffer_outputs)

	);

	APE_adder APE_adder_inst (
	    .APE_vals(buffer_outputs),
	    .MPE_vals(MPE_vals),

	    .enable(enable),

	    .output_vals(adder_outputs)
	);

	AF_array AF_array_inst (
		.finish(finish),
		.buffer_outputs(buffer_outputs),
		.AF_type(AF_type),
		.AF_outputs(AF_outputs)
	);

	Pool_array Pool_array_inst (
		.clock(clock),
		.reset(reset),
		// .finish(finish),
		.AF_outputs(AF_outputs),
		.Pool_type(Pool_type),
		.Pool_stride(Pool_stride),
		.Pool_kernel_size(Pool_kernel_size),
		.SRAM_r_en(r_enable),
		.SRAM_r(SRAM_r_out),
		.SRAM_c(SRAM_c_out),
		.SRAM_out(SRAM_out)
	);

endmodule