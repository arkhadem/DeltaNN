`include "sys_defs.svh"

module processing_element(
    input clock,
    input reset,

    input enable,

    input [(`BIN_LEN - 1) : 0] input_val,

    input [(`INPUT_WIDTH_LOG - 1) : 0] input_width_index,
    input [(`INPUT_HEIGHT_LOG - 1) : 0] input_height_index,

    input [(`BIN_LEN - 1) : 0] weight_val,
    input [(`DELTA_LEN - 1) : 0] delta_vals [(`DELTA_NUM - 1) : 0],
    input [(`DELTA_SIM_LEN - 1) : 0] delta_sims [(`DELTA_NUM - 1) : 0],

    input [(`INDEX_WIDTH - 1) : 0] index_vals [(`INDEX_NUM - 1) : 0],

    output reg w_en,
    output reg [(`OUTPUT_CHANNEL_LOG - 1) : 0] w_channel_index,
    output reg [(`OUTPUT_WIDTH_LOG - 1) : 0] w_height_index,
    output reg [(`OUTPUT_HEIGHT_LOG - 1) : 0] w_width_index,
    output reg [(`OUT_BIN_LEN - 1) : 0] w_val,

    output reg done
);

    wire index_count_down_zero;
    reg index_count_down_init;
    wire delta_count_down_zero, delta_count_down_restart;
    reg prev_stall_sign;
    reg mult_enable, is_mult_done;
    reg shift_enable;

    reg [(`INDEX_NUM_LOG - 1) : 0] index_count;
    reg [(`DELTA_NUM_LOG - 1) : 0] delta_count;

    wire [(`OUT_BIN_LEN - 1) : 0] mult_val;
    reg [(`OUT_BIN_LEN - 1) : 0] shift_val;
    reg [(`OUT_BIN_LEN - 1) : 0] accumulator, next_accumulator;

    wire stall_sign, next_stall_sign;

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

    always@(posedge clock) begin
        if(reset) begin
            delta_count = 0;
        end else if (delta_count_down_zero && enable && ~stall_sign) begin
            delta_count = delta_count + 1;
        end
    end

    delta_down_counter delta_down_counter_inst (
        .clock(clock),
        .reset(reset),
        .enable(enable && ~stall_sign && ~mult_enable),

        .count_init(delta_sims[delta_count]),
        .zero(delta_count_down_zero),
        .restart(delta_count_down_restart)
    );

    always@(posedge clock) begin
        if(reset) begin
            index_count = 0;
        end else if (enable == 1 && index_count_down_zero == 1 && (index_count_down_init == 0 || (index_count_down_init == 1 && index_vals[index_count][(`INDEX_WIDTH - 2) : 0] == 1))) begin
            index_count = index_count + 1;
        end
    end

    assign stall_sign = index_vals[index_count][`INDEX_WIDTH - 1];
    assign next_stall_sign = (index_count == `INDEX_NUM - 1) ? 0 : index_vals[index_count + 1][`INDEX_WIDTH - 1];

    always@(posedge clock) begin
        if(reset) begin
            prev_stall_sign = 0;
        end else if (enable) begin
            prev_stall_sign = stall_sign;
        end
    end

    always@(*) begin
        if(prev_stall_sign == 0 && stall_sign == 1) begin
            index_count_down_init = 1;
        end else begin
            index_count_down_init = 0;
        end
    end

    index_down_counter index_down_counter_inst (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .init(index_count_down_init),

        .count_init(index_vals[index_count][(`INDEX_WIDTH - 2) : 0]),
        .zero(index_count_down_zero)
    );

    always@(posedge clock) begin
        if(reset) begin
            is_mult_done = 0;
        end else begin
            if(is_mult_done == 0 && enable == 1 && stall_sign == 0) begin
                is_mult_done = 1;
            end
        end
    end

    always@(*) begin
        if(enable == 1 && is_mult_done == 0 && stall_sign == 0) begin
            mult_enable = 1;
        end else begin
            mult_enable = 0;
        end
    end

    multiplier mult_inst(
        .input_val1(input_val),
        .input_val2(weight_val),
        .enable(mult_enable),

        .output_val(mult_val)
    );

    always@(*) begin
        if(delta_count_down_restart) begin
            shift_enable = 1;
        end else begin
            shift_enable = 0;
        end
    end

    shifter shift_inst(
        .input_val1(input_val),
        .input_val2(delta_vals[delta_count]),
        .enable(shift_enable && enable),

        .output_val(shift_val)
    );

    assign w_en = ~stall_sign && enable;
    assign w_channel_index = index_vals[index_count][`OUTPUT_CHANNEL_LOG+`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG - 1 : `KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG];
    assign w_height_index = input_height_index - index_vals[index_count][`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG - 1 : `KERNEL_WIDTH_LOG];
    assign w_width_index = input_width_index - index_vals[index_count][`KERNEL_WIDTH_LOG - 1 : 0];
    assign w_val = next_accumulator;
    assign done = (stall_sign == 1 && (index_vals[index_count][(`INDEX_WIDTH - 2) : 0] == 0)) ? 1 : 0;

endmodule
