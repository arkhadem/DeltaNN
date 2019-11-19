`include "sys_defs.svh"

module delta_down_counter(
    input clock,
    input reset,
    input enable,

    input [(`DELTA_SIM_LEN - 1):0] count_init,
    output zero,
    output restart
);

    reg [(`DELTA_SIM_LEN - 1):0] count;

    always@(posedge clock)begin
        if(reset)begin
            count = 0;
        end else if(enable) begin
            if (count == 0) begin
                count = count_init - 1;
            end else begin
                count = count - 1;
            end
        end
    end

    assign zero = ((count == 0 && count_init == 1) || count == 1) ? 1'b1 : 1'b0;
    assign restart = (count == 0 && enable == 1) ? 1'b1 : 1'b0;

endmodule
