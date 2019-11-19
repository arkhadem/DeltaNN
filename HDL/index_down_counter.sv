`include "sys_defs.svh"

module index_down_counter (
    input clock,
    input reset,
    input enable,
    input init,

    input [(`OUTPUT_CHANNEL_LOG+`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG - 1):0] count_init,
    output zero
);

    reg [(`OUTPUT_CHANNEL_LOG+`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG - 1):0] count;

    always@(posedge clock)begin
        if(reset)begin
            count = 0;
        end else begin
            if (init) begin
                count = count_init - 1;
            end else if(count != 0 && enable) begin
                count = count - 1;
            end
        end
    end

    assign zero = ((init == 1 && count_init == 1) || (init == 0 && (count == 0 || count == 1))) ? 1'b1 : 1'b0;

endmodule
