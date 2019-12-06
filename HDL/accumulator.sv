`include "sys_defs.svh"

module accumulator(
    input clock,
    input reset,
    input enable,
    input mult_enable,
    input shift_enable,

    input [(`OUT_BIN_LEN - 1) : 0] mult_val,
    input [(`OUT_BIN_LEN - 1) : 0] shift_val,

    output reg [(`OUT_BIN_LEN - 1) : 0] w_val
);
    reg [(`OUT_BIN_LEN - 1) : 0] accumulator, next_accumulator;

    always@(*) begin
        next_accumulator = accumulator;
        if(mult_enable) begin
            next_accumulator = mult_val;
        end else if(shift_enable) begin
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
