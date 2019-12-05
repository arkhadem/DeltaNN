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

    output reg [(`OUT_BIN_LEN - 1) : 0] w_val

);


    wire [(`OUT_BIN_LEN - 1) : 0] mult_val;
    reg [(`OUT_BIN_LEN - 1) : 0] shift_val;
    reg [(`OUT_BIN_LEN - 1) : 0] accumulator, next_accumulator;

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

    always@(*) begin
        next_accumulator = accumulator;
        if(mult_enable) begin
            next_accumulator = mult_val;
        end else if(delta_count_down_restart) begin
            next_accumulator = accumulator + shift_val;
        end
    end

    always@(posedge clock) begin
        if(reset) begin
            accumulator = 0;
        end else if(enable) begin
            accumulator = next_accumulator;
        end
    end

    assign w_val = next_accumulator;

endmodule
