`include "sys_defs.svh"

module PU_controller(
    input clock,
    input reset,
    input start,

    // Tile configuration
    input [($clog2(`INPUT_CHANNEL) - 1) : 0] IC_Num,
    input [($clog2(`OUTPUT_CHANNEL) - 1) : 0] OC_Num,

    // Index buffer signal
    input [(`INPUT_CHANNEL - 1) : 0] line_finished,

    // Input line signal
    output reg [(`INPUT_CHANNEL - 1) : 0] in_line_start,

    // APE control
    output reg [(`OUTPUT_CHANNEL - 1) : 0] APE_enable,
    
    // Final signal
    output reg total_finished

);

	parameter   WAIT_FOR_START = 3'd0,
                START_SIGNAL = 3'd1,
                OPERATION = 3'd2,
                DONE_SIGNAL = 3'd3;

    reg [2:0] state, next_state;

    always@(*) begin
        next_state = WAIT_FOR_START;
        case (state)
            WAIT_FOR_START:
                if(start)
                    if(IC_Num == 0 || OC_Num == 0)
                        next_state = DONE_SIGNAL;
                    else
                        next_state = START_SIGNAL;
                else
                    next_state = WAIT_FOR_START;

            START_SIGNAL: next_state = OPERATION;

            OPERATION:
                if(line_finished == {`INPUT_CHANNEL{1'b1}})
                    next_state = DONE_SIGNAL;
                else
                    next_state = OPERATION;

           	DONE_SIGNAL: next_state = WAIT_FOR_START;

            default: next_state = WAIT_FOR_START;
        endcase
    end

    always@(*) begin
        in_line_start = 0;
        APE_enable = 0;
        total_finished = 0;
        case (state)
            START_SIGNAL: begin
                in_line_start = 0;
                for (int i = 0; i < IC_Num; i++) begin
                    in_line_start[i] = 1'b1;
                end
            end
            
            OPERATION: begin
                APE_enable = 0;
                for (int i = 0; i < OC_Num; i++) begin
                    APE_enable[i] = 1'b1;
                end
            end

            DONE_SIGNAL: begin
                total_finished = 1'b1;
            end

            default: begin
                in_line_start = 0;
                APE_enable = 0;
                total_finished = 0;
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
endmodule