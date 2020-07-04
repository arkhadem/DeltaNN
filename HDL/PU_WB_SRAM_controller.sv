`include "sys_defs.svh"

module PU_WB_SRAM_controller (
    input clock,
    input reset,

    input [(`WEIGHT_SRAM_LEN - 1) : 0] WB_SRAM_in,
    input WB_SRAM_ready,
    output reg WB_SRAM_read,
    output reg [31 : 0] WB_SRAM_address,

    input [31 : 0] WB_SRAM_idx_start_address,
    input [31 : 0] WB_SRAM_unique_start_address,
    input [31 : 0] WB_SRAM_repetition_start_address,


    // Module partial addresses for WB_SRAM access
    input [31 : 0] unique_buffer_word_counter [(`INPUT_CHANNEL - 1) : 0],
    input [31 : 0] repetition_buffer_word_counter [(`INPUT_CHANNEL - 1) : 0],
    input [31 : 0] idx_buffer_word_counter [(`INPUT_CHANNEL - 1) : 0],

    // WB buffers read and ready ports
    input [(`INPUT_CHANNEL - 1) : 0] unique_buffer_word_read,
    output reg[(`INPUT_CHANNEL - 1) : 0] unique_buffer_word_ready,
    input [(`INPUT_CHANNEL - 1) : 0] repetition_buffer_word_read,
    output reg[(`INPUT_CHANNEL - 1) : 0] repetition_buffer_word_ready,
    input [(`INPUT_CHANNEL - 1) : 0] idx_buffer_word_read,
    output reg[(`INPUT_CHANNEL - 1) : 0] idx_buffer_word_ready

);

    reg [$clog2(`INPUT_CHANNEL) - 1 : 0] intra_channel_turn;
    reg [1:0] inter_channel_turn;

    always@(posedge clock) begin
        if(reset) begin
            intra_channel_turn = 0;
            inter_channel_turn = 0;
        end else begin
            for (int i = 0; i < `INPUT_CHANNEL; i++) begin
                unique_buffer_word_ready[i] = 0;
                repetition_buffer_word_ready[i] = 0;
                idx_buffer_word_ready[i] = 0;
            end
            if(inter_channel_turn == 0) begin       // no module in current channel is using SRAM
                if(idx_buffer_word_read[intra_channel_turn] == 1'b1) begin
                    inter_channel_turn = 2'd1;
                    WB_SRAM_read = 1'b1;
                    WB_SRAM_address = (intra_channel_turn << $clog2(`MAX_WEIGHT_LEN_BYTE))                 // line number in tile
                                    + (idx_buffer_word_counter[intra_channel_turn] << 2)                // word number in line
                                    + WB_SRAM_idx_start_address;                                        // start address of tile
                end else if(repetition_buffer_word_read[intra_channel_turn] == 1'b1) begin
                    inter_channel_turn = 2'd2;
                    WB_SRAM_read = 1'b1;
                    WB_SRAM_address = (intra_channel_turn << $clog2(`MAX_WEIGHT_LEN_BYTE))          // line number in tile
                                    + (repetition_buffer_word_counter[intra_channel_turn] << 2)         // word number in line
                                    + WB_SRAM_repetition_start_address;                                 // start address of tile
                end else if(unique_buffer_word_read[intra_channel_turn] == 1'b1) begin
                    inter_channel_turn = 2'd3;
                    WB_SRAM_read = 1'b1;
                    WB_SRAM_address = (intra_channel_turn << $clog2(`MAX_WEIGHT_LEN_BYTE))              // line number in tile
                                    + (unique_buffer_word_counter[intra_channel_turn] << 2)             // word number in line
                                    + WB_SRAM_unique_start_address;                                     // start address of tile
                end else begin
                    WB_SRAM_read = 1'b0;
                    intra_channel_turn = intra_channel_turn + 1;
                end
            end else begin
                if(WB_SRAM_ready == 1'b1) begin
                    case (inter_channel_turn)
                        2'd1: begin
                            idx_buffer_word_ready[intra_channel_turn] = 1'b1;
                            if(repetition_buffer_word_read[intra_channel_turn] == 1'b1) begin
                                inter_channel_turn = 2'd2;
                                WB_SRAM_read = 1'b1;
                                WB_SRAM_address = (intra_channel_turn << $clog2(`MAX_WEIGHT_LEN_BYTE))          // line number in tile
                                                + (repetition_buffer_word_counter[intra_channel_turn] << 2)         // word number in line
                                                + WB_SRAM_repetition_start_address;                                 // start address of tile
                            end else if(unique_buffer_word_read[intra_channel_turn] == 1'b1) begin
                                inter_channel_turn = 2'd3;
                                WB_SRAM_read = 1'b1;
                                WB_SRAM_address = (intra_channel_turn << $clog2(`MAX_WEIGHT_LEN_BYTE))              // line number in tile
                                                + (unique_buffer_word_counter[intra_channel_turn] << 2)             // word number in line
                                                + WB_SRAM_unique_start_address;                                     // start address of tile
                            end else begin
                                WB_SRAM_read = 1'b0;
                                inter_channel_turn = 2'd0;
                                intra_channel_turn = intra_channel_turn + 1;
                            end
                        end
                        2'd2: begin
                            repetition_buffer_word_ready[intra_channel_turn] = 1'b1;
                            if(unique_buffer_word_read[intra_channel_turn] == 1'b1) begin
                                inter_channel_turn = 2'd3;
                                WB_SRAM_read = 1'b1;
                                WB_SRAM_address = (intra_channel_turn << $clog2(`MAX_WEIGHT_LEN_BYTE))              // line number in tile
                                                + (unique_buffer_word_counter[intra_channel_turn] << 2)             // word number in line
                                                + WB_SRAM_unique_start_address;                                     // start address of tile
                            end else begin
                                WB_SRAM_read = 1'b0;
                                inter_channel_turn = 2'd0;
                                intra_channel_turn = intra_channel_turn + 1;
                            end
                        end
                        2'd3: begin
                            unique_buffer_word_ready[intra_channel_turn] = 1'b1;
                            WB_SRAM_read = 1'b0;
                            inter_channel_turn = 2'd0;
                            intra_channel_turn = intra_channel_turn + 1;
                        end
                        default : /* default */;
                    endcase
                end
            end
        end
    end




endmodule