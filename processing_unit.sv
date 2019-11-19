`include "sys_defs.svh"

module processing_unit(
    input clock,
    input reset,
    input start,

    input [(`BIN_LEN - 1) : 0] input_val [`INPUT_CHANNEL - 1 : 0][`INPUT_HEIGHT - 1 : 0][`INPUT_WIDTH - 1 : 0],

    input [(`BIN_LEN - 1) : 0] weight_val [`INPUT_CHANNEL - 1 : 0],
    input [(`DELTA_BIN_LEN - 1) : 0] delta_weight_vals [`INPUT_CHANNEL - 1 : 0][('OUTPUT_CHANNEL * `KERNEL_HEIGHT * `KERNEL_WIDTH - 1) : 0],

    input [(`INDEX_LEN - 1) : 0] index_vals [`INPUT_CHANNEL - 1 : 0][(`OUTPUT_CHANNEL * `KERNEL_HEIGHT * `KERNEL_WIDTH - 1) : 0],

    output [(`OUT_BIN_LEN - 1) : 0] output_val [`OUTPUT_CHANNEL - 1 : 0][`OUTPUT_HEIGHT - 1 : 0][`OUTPUT_WIDTH - 1 : 0],
    output output_valid,

    output reg done
);

    wire zero_flag;
    genvar i, j;
    wire [(`OUT_BIN_LEN - 1) : 0] output_vals [(`KERNEL_HEIGHT - 1) : 0][(`KERNEL_WIDTH - 1) : 0];
    reg [(`OUT_BIN_LEN - 1) : 0] init_vals [(`KERNEL_HEIGHT - 1) : 0][(`KERNEL_WIDTH - 1) : 0];
    wire [(`BIN_WIDTH - 1) : 0] selector;
    wire zero_select;

    reg enables [(`KERNEL_HEIGHT - 1) : 0][(`KERNEL_WIDTH - 1) : 0];

    reg [(`INPUT_CHANNEL_LOG - 1) : 0] input_channel_index;
    reg [(`OUTPUT_CHANNEL_LOG - 1) : 0] output_channel_index;
    reg [(`INPUT_WIDTH_LOG - 1) : 0] input_width_index;
    reg [(`INPUT_HEIGHT_LOG - 1) : 0] input_height_index;
    reg [(`KERNEL_WIDTH_LOG - 1) : 0] kernel_width_index;
    reg [(`KERNEL_HEIGHT_LOG - 1) : 0] kernel_height_index;

    reg [(`OUT_BIN_LEN - 1) : 0] stored_partial_sums [(`KERNEL_HEIGHT - 2) : 0][(`INPUT_WIDTH - 1) : 0];

    reg down_counter_reset, down_counter_enable;
    reg FSM_selector_reset, FSM_selector_enable;
    reg PE_reset, PE_enable, PE_init;
    reg index_reset, index_enable;
    reg partial_sum_reset, partial_sum_enable;

    reg output_valid_tmp;

    parameter   WAIT_FOR_START = 3'd0,
                RESET_SIGNALS = 3'd1,
                WAIT_FOR_INPUT = 3'd2,
                INIT_SIGNALS = 3'd3,
                WAIT_FOR_ZERO = 3'd4,
                OUTPUT_IS_READY = 3'd5,
                INDEX_INCREMENT = 3'd6,
                DONE_FLAG = 3'd7;

    reg [2:0] state, next_state;

    always@(*) begin
        next_state = WAIT_FOR_START;
        case (state)
            WAIT_FOR_START:
                if(start)
                    next_state = RESET_SIGNALS;
                else
                    next_state = WAIT_FOR_START;

            RESET_SIGNALS: next_state = WAIT_FOR_INPUT;

            WAIT_FOR_INPUT:
                if(input_ready)
                    next_state = INIT_SIGNALS;
                else
                    next_state = WAIT_FOR_INPUT;

            INIT_SIGNALS: next_state = WAIT_FOR_ZERO;

            WAIT_FOR_ZERO:
                if(zero_flag == 1)
                    next_state = OUTPUT_IS_READY;
                else
                    next_state = WAIT_FOR_ZERO;

            OUTPUT_IS_READY:
                next_state = INDEX_INCREMENT;

            INDEX_INCREMENT:
                if((width_index == `INPUT_WIDTH - 1) && (height_index == `INPUT_HEIGHT - 1))
                    next_state = DONE_FLAG;
                else
                    next_state = WAIT_FOR_INPUT;

            DONE_FLAG: next_state = WAIT_FOR_START;

            default: next_state = WAIT_FOR_START;
        endcase
    end

    always@(state) begin
        input_req = 0;
        down_counter_reset = 0;
        down_counter_enable = 0;
        FSM_selector_reset = 0;
        FSM_selector_enable = 0;
        PE_reset = 0;
        PE_enable = 0;
        PE_init = 0;
        index_reset = 0;
        index_enable = 0;
        partial_sum_reset = 0;
        partial_sum_enable = 0;
        output_valid_tmp = 0;
        done = 0;

        case (state)
            RESET_SIGNALS: begin
                index_reset = 1;
                PE_reset = 1;
                partial_sum_reset = 1;
            end

            WAIT_FOR_INPUT: input_req = 1;

            INIT_SIGNALS: begin
                PE_init = 1;
                down_counter_reset = 1;
                FSM_selector_reset = 1;
            end

            WAIT_FOR_ZERO: begin
                PE_enable = 1;
                down_counter_enable = 1;
                FSM_selector_enable = 1;
            end

            OUTPUT_IS_READY: begin
                partial_sum_enable = 1;
                output_valid_tmp = 1;
            end

            INDEX_INCREMENT: begin
                index_enable = 1;
            end

            DONE_FLAG: done = 1;

            default: begin
                input_req = 0;
                down_counter_reset = 0;
                down_counter_enable = 0;
                FSM_selector_reset = 0;
                FSM_selector_enable = 0;
                PE_reset = 0;
                PE_enable = 0;
                PE_init = 0;
                index_reset = 0;
                index_enable = 0;
                partial_sum_reset = 0;
                partial_sum_enable = 0;
                output_valid_tmp = 0;
                done = 0;
            end
        endcase
    end

    always@(posedge clock) begin
        if(reset) begin
            state = WAIT_FOR_START;
        end else begin
            state = next_state;
        end
    end


    down_counter down_counter_inst(
        .clock(clock),
        .reset(down_counter_reset|reset),
        .enable(down_counter_enable),

        .count_init(input_val),
        .zero(zero_flag)
    );

    FSM_selector FSM_selector_inst(
        .clock(clock),
        .reset(FSM_selector_reset|reset),
        .enable(FSM_selector_enable),

        .selector(selector),
        .zero_select(zero_select)
    );

    for (i = 0; i < `KERNEL_HEIGHT; i = i + 1) begin : PE_row
        for (j = 0; j < `KERNEL_HEIGHT; j = j + 1) begin : PE_column
            processing_element PEs(
                .clock(clock),
                .reset(PE_reset|reset),
                .enable(enables[i][j] && PE_enable),
                .init(PE_init),
                .selector(selector),
                .zero_select(zero_select),
                .init_val(init_vals[i][j]),
                .weight_val(weight_vals[i][j]),
                .output_val(output_vals[i][j])
            );
        end
    end

    always@(*) begin
        for (int i = 0; i < `KERNEL_HEIGHT; i = i + 1) begin
            for (int j = 1; j < `KERNEL_HEIGHT; j = j + 1) begin
                init_vals[i][j] = output_vals[i][j-1];
            end
            for (int j = 0; j < `KERNEL_HEIGHT; j = j + 1) begin
                enables[i][j] = ((i <= height_index) && (j <= width_index) && (width_index + `KERNEL_WIDTH - 1 - j < `INPUT_WIDTH) && (height_index + `KERNEL_HEIGHT - 1 - i < `INPUT_HEIGHT)) ? 1 : 0;
            end
        end
        for (int i = 1; i < `KERNEL_HEIGHT; i = i + 1) begin
            init_vals[i][0] = stored_partial_sums[i - 1][width_index];
        end
        init_vals[0][0] = 0;
    end

    assign output_val = output_vals[(`KERNEL_HEIGHT - 1)][(`KERNEL_WIDTH - 1)];
    assign output_valid = ((output_valid_tmp == 1) && (width_index >= (`KERNEL_WIDTH - 1)) && (height_index >= (`KERNEL_HEIGHT - 1))) ? 1 : 0;

    always@(posedge clock) begin
        if(index_reset) begin
            width_index = 0;
            height_index = 0;
        end else if (index_enable) begin
            if(width_index == `INPUT_WIDTH - 1) begin
                width_index = 0;
                height_index = height_index + 1;
            end else begin
                width_index = width_index + 1;
            end
        end
    end

    always@(posedge clock) begin
        if(partial_sum_reset) begin
            for(int i = 0; i < `KERNEL_HEIGHT - 1; i++) begin
                for(int j = 0; j < `INPUT_WIDTH; j++) begin
                    stored_partial_sums[i][j] = 0;
                end
            end
        end else if(partial_sum_enable) begin
            for(int i = 0; i < `KERNEL_HEIGHT - 1; i++) begin
                stored_partial_sums[i][width_index - (`KERNEL_WIDTH - 1)] = output_vals[i][(`KERNEL_WIDTH - 1)];
            end
        end
    end

endmodule
