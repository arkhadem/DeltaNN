`include "sys_defs.svh"

module shifter(
    input [(`BIN_LEN - 1) : 0] input_val1,
    input [(`DELTA_LEN - 1) : 0] input_val2,
    input enable,

    output [(`OUT_BIN_LEN - 1) : 0] output_val
);

    wire [(`BIN_LEN - 1) : 0] val1, val2;

    assign val1 = (enable == 1) ? input_val1 : {`BIN_LEN{1'bz}};
    assign val2 = (enable == 1) ? input_val2 : {`BIN_LEN{1'bz}};

    assign output_val = val1 << val2;

endmodule
