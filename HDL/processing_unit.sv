`include "sys_defs.svh"

module processing_unit(
    input clock,
    input reset,
    input enable,

    input [(`BIN_LEN - 1) : 0] input_vals [`INPUT_CHANNEL - 1 : 0][`INPUT_HEIGHT - 1 : 0][`INPUT_WIDTH - 1 : 0],

    input [(`BIN_LEN - 1) : 0] weight_vals [`INPUT_CHANNEL - 1 : 0],

    input [(`DELTA_LEN - 1) : 0] delta_vals [`INPUT_CHANNEL - 1 : 0][(`DELTA_NUM - 1) : 0],
    input [(`DELTA_SIM_LEN - 1) : 0] delta_sims [`INPUT_CHANNEL - 1 : 0][(`DELTA_NUM - 1) : 0],


    input [(`INDEX_WIDTH - 1) : 0] index_vals [(`INPUT_CHANNEL - 1) : 0][(`INDEX_NUM - 1) : 0],

    output [(`OUT_BIN_LEN - 1) : 0] output_vals [`OUTPUT_CHANNEL - 1 : 0][`OUTPUT_HEIGHT - 1 : 0][`OUTPUT_WIDTH - 1 : 0],

    output reg done
);

    reg [(`INPUT_CHANNEL - 1) : 0] mult_enable;
    reg [(`INPUT_CHANNEL - 1) : 0] shift_enable;
    reg [(`INPUT_CHANNEL - 1) : 0] delta_count_down_restart;
    wire [(`OUT_BIN_LEN - 1) : 0] w_val [(`INPUT_CHANNEL - 1) : 0][(`INPUT_HEIGHT - 1) : 0][(`INPUT_WIDTH - 1) : 0];

    reg [(`INPUT_CHANNEL - 1) : 0] w_en;

    wire [(`INPUT_CHANNEL - 1) : 0] index_count_down_zero;
    reg [(`INPUT_CHANNEL - 1) : 0] index_count_down_init;
    wire [(`INPUT_CHANNEL - 1) : 0] delta_count_down_zero;
    reg [(`INPUT_CHANNEL - 1) : 0] prev_stall_sign;
    reg [(`INPUT_CHANNEL - 1) : 0] is_mult_done;

    reg [(`INDEX_NUM_LOG - 1) : 0] index_count [(`INPUT_CHANNEL - 1) : 0];
    reg [(`DELTA_NUM_LOG - 1) : 0] delta_count [(`INPUT_CHANNEL - 1) : 0];

    reg [(`INPUT_CHANNEL - 1) : 0] stall_sign;
    reg [(`INPUT_CHANNEL - 1) : 0] next_stall_sign;

    reg [(`INPUT_CHANNEL - 1) : 0] PE_enables;

    genvar ch_itr_gen, r_itr_gen, c_itr_gen;

    for (ch_itr_gen = 0; ch_itr_gen < `INPUT_CHANNEL; ch_itr_gen = ch_itr_gen + 1) begin : PE_channel
        for (r_itr_gen = 0; r_itr_gen < `INPUT_HEIGHT; r_itr_gen = r_itr_gen + 1) begin : PE_row
            for (c_itr_gen = 0; c_itr_gen < `INPUT_WIDTH; c_itr_gen = c_itr_gen + 1) begin : PE_column
                processing_element PEs(
                    .clock(clock),
                    .reset(reset),

                    .enable(enable && PE_enables[ch_itr_gen]),

                    .mult_enable(mult_enable[ch_itr_gen]),
                    .shift_enable(shift_enable[ch_itr_gen]),
                    .delta_count_down_restart(delta_count_down_restart[ch_itr_gen]),

                    .input_val(input_vals[ch_itr_gen][r_itr_gen][c_itr_gen]),
                    .weight_val(weight_vals[ch_itr_gen]),
                    .delta_val(delta_vals[ch_itr_gen][delta_count[ch_itr_gen]]),

                    .w_val(w_val[ch_itr_gen][r_itr_gen][c_itr_gen])

                );
            end
        end
    end

    always@(posedge clock) begin
        if(reset == 1'b1) begin
            for(int i = 0; i < `INPUT_CHANNEL; i++) begin
                PE_enables[i] = 1;
            end
        end else if(enable) begin
            for(int i = 0; i < `INPUT_CHANNEL; i++) begin
                if(PE_enables[i] == 1) begin
                    if(index_vals[i][index_count[i]] == {1'b1, {(`INDEX_WIDTH-1){1'b0}}}) begin
                        PE_enables[i] = 0;
                    end
                end
            end
        end
    end


    output_buffer output_buffer_inst(
        .clock(clock),
        .reset(reset),
        .enable(enable),

        .w_en(w_en),
        .index_vals(index_vals),
        .index_count(index_count),
        .w_val(w_val),

        .output_vals(output_vals)
    );


    always@(*) begin
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            w_en[ch_itr] = ~stall_sign[ch_itr] && enable;
        end
    end


    always@(posedge clock) begin
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            if(reset) begin
                delta_count[ch_itr] = 0;
            end else if (delta_count_down_zero[ch_itr] && enable && ~stall_sign[ch_itr]) begin
                delta_count[ch_itr] = delta_count[ch_itr] + 1;
            end
        end
    end

    for (ch_itr_gen = 0; ch_itr_gen < `INPUT_CHANNEL; ch_itr_gen = ch_itr_gen + 1) begin : delta_down_channel
        delta_down_counter delta_down_counter_inst (
            .clock(clock),
            .reset(reset),
            .enable(enable && ~stall_sign[ch_itr_gen] && ~mult_enable[ch_itr_gen]),

            .count_init(delta_sims[ch_itr_gen][delta_count[ch_itr_gen]]),
            .zero(delta_count_down_zero[ch_itr_gen]),
            .restart(delta_count_down_restart[ch_itr_gen])
        );
    end

    always@(posedge clock) begin
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            if(reset) begin
                index_count[ch_itr] = 0;
            end else if (index_vals[ch_itr][index_count[ch_itr]] != {1'b1, {(`INDEX_WIDTH-1){1'b0}}} && enable == 1 && index_count_down_zero[ch_itr] == 1 && (index_count_down_init[ch_itr] == 0 || (index_count_down_init[ch_itr] == 1 && index_vals[ch_itr][index_count[ch_itr]][(`INDEX_WIDTH - 2) : 0] == 1))) begin
                index_count[ch_itr] = index_count[ch_itr] + 1;
            end
        end
    end

    always@(*) begin
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            stall_sign[ch_itr] = index_vals[ch_itr][index_count[ch_itr]][`INDEX_WIDTH - 1];
            next_stall_sign[ch_itr] = (index_count[ch_itr] == `INDEX_NUM - 1) ? 0 : index_vals[ch_itr][index_count[ch_itr] + 1][`INDEX_WIDTH - 1];
        end
    end

    always@(posedge clock) begin
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            if(reset) begin
                prev_stall_sign[ch_itr] = 0;
            end else if (enable) begin
                prev_stall_sign[ch_itr] = stall_sign[ch_itr];
            end
        end
    end

    always@(*) begin
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            if(prev_stall_sign[ch_itr] == 0 && stall_sign[ch_itr] == 1) begin
                index_count_down_init[ch_itr] = 1;
            end else begin
                index_count_down_init[ch_itr] = 0;
            end
        end
    end

    for (ch_itr_gen = 0; ch_itr_gen < `INPUT_CHANNEL; ch_itr_gen = ch_itr_gen + 1) begin : index_down_channel
        index_down_counter index_down_counter_inst (
            .clock(clock),
            .reset(reset),
            .enable(enable),
            .init(index_count_down_init[ch_itr_gen]),

            .count_init(index_vals[ch_itr_gen][index_count[ch_itr_gen]][(`INDEX_WIDTH - 2) : 0]),
            .zero(index_count_down_zero[ch_itr_gen])
        );
    end

    always@(posedge clock) begin
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            if(reset) begin
                is_mult_done[ch_itr] = 0;
            end else begin
                if(is_mult_done[ch_itr] == 0 && enable == 1 && stall_sign[ch_itr] == 0) begin
                    is_mult_done[ch_itr] = 1;
                end
            end
        end
    end

    always@(*) begin
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            if(enable == 1 && is_mult_done[ch_itr] == 0 && stall_sign[ch_itr] == 0) begin
                mult_enable[ch_itr] = 1;
            end else begin
                mult_enable[ch_itr] = 0;
            end
        end
    end

    always@(*) begin
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            if(delta_count_down_restart[ch_itr]) begin
                shift_enable[ch_itr] = 1;
            end else begin
                shift_enable[ch_itr] = 0;
            end
        end
    end

    always@(posedge clock) begin
        done = 1;
        for (int ch_itr = 0; ch_itr < `INPUT_CHANNEL; ch_itr = ch_itr + 1) begin
            if(index_vals[ch_itr][index_count[ch_itr]] != {1'b1, {(`INDEX_WIDTH-1){1'b0}}}) begin
                done = 0;
            end
        end
    end

endmodule
