`include "sys_defs.svh"

module PU_in_line_controller (
    input clock,
    input reset,
    input start,

    // MPE signals
    output reg MPE_enable,
    input MPE_out_ready,

    // Unique weight buffer signals
    output reg unique_buffer_enable,
    input unique_buffer_busy,
    input weight_valid,
    input unique_buffer_filled,

    // Repetition buffer signals
    output reg repetition_buffer_enable,
    input repetition_buffer_busy,
    input new_weight,
    input repetition_buffer_filled,

    // Idx buffer signals
    output reg idx_buffer_enable,
    input is_index,
    input finished,
    input idx_buffer_filled
);

    parameter   WAIT_FOR_START = 2'd0,
              BUFFER_FILL = 2'd1,
              OPERATION = 2'd2;

    reg [1:0] state, next_state;

    always@(*) begin
        next_state = WAIT_FOR_START;
        case (state)
            WAIT_FOR_START:
                if(start)
                    next_state = OPERATION;
                else
                    next_state = WAIT_FOR_START;

            BUFFER_FILL:
                if(unique_buffer_filled == 1 && repetition_buffer_filled == 1 && idx_buffer_filled == 1)
                    next_state = OPERATION;
                else
                    next_state = BUFFER_FILL;

            OPERATION:
                if(finished)
                    next_state = WAIT_FOR_START;
                else
                    next_state = OPERATION;

            default: next_state = WAIT_FOR_START;
        endcase
    end

    always@(posedge clock) begin
        if(reset) begin
            state = WAIT_FOR_START;
        end else begin
            state = next_state;
        end
    end

    always@(*) begin
        MPE_enable = 0;
        unique_buffer_enable = 0;
        repetition_buffer_enable = 0;
        idx_buffer_enable = 0;
        if(state == BUFFER_FILL) begin
            if(repetition_buffer_filled == 0) begin
                repetition_buffer_enable = 1;
            end
            if(unique_buffer_filled == 0) begin
                unique_buffer_enable = 1;
            end
            if(idx_buffer_filled == 0) begin
                idx_buffer_enable = 1;
            end
        end else if(state == OPERATION) begin
            if(is_index == 1'b1 && unique_buffer_busy == 1'b0) begin
                repetition_buffer_enable = 1'b1;
            end

            if(new_weight == 1'b1 && MPE_out_ready == 1'b1) begin
                unique_buffer_enable = 1'b1;
            end

            if(weight_valid == 1'b1) begin
                MPE_enable = 1'b1;
            end

            if(repetition_buffer_busy == 1'b0) begin
                idx_buffer_enable = 1'b1;
            end
        end
    end

endmodule