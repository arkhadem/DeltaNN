`include "sys_defs.svh"

module processing_element(
    input clock,
    input reset,

    input enable,

    input mult_enable,
    input shift_enable,
    input delta_count_down_restart,

    input [(`BIN_LEN - 1) : 0] input_val,
    input [(`BIN_LEN - 1) : 0] weight_val,
    input [(`DELTA_LEN - 1) : 0] delta_val,

    output [(`OUT_BIN_LEN - 1) : 0] w_val

);


    wire [(`OUT_BIN_LEN - 1) : 0] mult_val;
    wire [(`OUT_BIN_LEN - 1) : 0] shift_val;

    multiplier mult_inst(
        .input_val1(input_val),
        .input_val2(weight_val),
        .enable(mult_enable && enable),

        .output_val(mult_val)
    );

    shifter shift_inst(
        .input_val1(input_val),
        .input_val2(delta_val),
        .enable(shift_enable && enable),

        .output_val(shift_val)
    );

    accumulator accumulator_inst(
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .mult_enable(mult_enable),
        .shift_enable(delta_count_down_restart),

        .mult_val(mult_val),
        .shift_val(shift_val),

        .w_val(w_val)
    );

endmodule
