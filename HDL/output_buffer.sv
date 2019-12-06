`include "sys_defs.svh"

module output_buffer(
    input clock,
    input reset,
    input enable,

    input [(`INPUT_CHANNEL - 1) : 0] w_en,
    input [(`INDEX_WIDTH - 1) : 0] index_vals [(`INPUT_CHANNEL - 1) : 0][(`INDEX_NUM - 1) : 0],
    input [(`INDEX_NUM_LOG - 1) : 0] index_count [(`INPUT_CHANNEL - 1) : 0],
    input [(`OUT_BIN_LEN - 1) : 0] w_val [(`INPUT_CHANNEL - 1) : 0][(`INPUT_HEIGHT - 1) : 0][(`INPUT_WIDTH - 1) : 0],

    output reg [(`OUT_BIN_LEN - 1) : 0] output_vals [(`OUTPUT_CHANNEL) - 1 : 0][(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH) - 1 : 0]
);
    always@(posedge clock) begin
        if(reset) begin
            for(int ch_itr = 0; ch_itr < `OUTPUT_CHANNEL; ch_itr++) begin
                for (int r_itr = 0; r_itr < `OUTPUT_HEIGHT; r_itr = r_itr + 1) begin
                    for (int c_itr = 0; c_itr < `OUTPUT_WIDTH; c_itr = c_itr + 1) begin
                        output_vals[ch_itr][r_itr][c_itr] = 0;
                    end
                end
            end
        end else if (enable) begin
            for(int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr++) begin
                if(w_en[ch_itr] == 1) begin
                    for (int r_itr = 0; r_itr < `INPUT_HEIGHT; r_itr = r_itr + 1) begin
                        for (int c_itr = 0; c_itr < `INPUT_WIDTH; c_itr = c_itr + 1) begin
                            if((r_itr >= index_vals[ch_itr][index_count[ch_itr]][`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG - 1 : `KERNEL_WIDTH_LOG]) && (c_itr >= index_vals[ch_itr][index_count[ch_itr]][`KERNEL_WIDTH_LOG - 1 : 0])) begin
                                output_vals[index_vals[ch_itr][index_count[ch_itr]][`OUTPUT_CHANNEL_LOG+`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG - 1 : `KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG]][r_itr - index_vals[ch_itr][index_count[ch_itr]][`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG - 1 : `KERNEL_WIDTH_LOG]][c_itr - index_vals[ch_itr][index_count[ch_itr]][`KERNEL_WIDTH_LOG - 1 : 0]] += {{(`OUT_BIN_LEN - `BIN_LEN){1'b0}}, w_val[ch_itr][r_itr][c_itr]};
                            end
                        end
                    end
                end
            end
        end
    end
endmodule
