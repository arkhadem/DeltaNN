`include "sys_defs.svh"

module processing_unit(
    input clock,
    input reset,
    input start,

    // NN configuration
    input [(`BIN_LEN - 1) : 0] inputs [(`INPUT_CHANNEL - 1) : 0][(`INPUT_HEIGHT - 1) : 0][(`INPUT_WIDTH - 1) : 0],
    input [2 : 0] stride,
    input [1 : 0] AF_type,
    input [1 : 0] Pool_type,
    input [2 : 0] Pool_stride,
    input [2 : 0] Pool_kernel_size,
    input [($clog2(`MAX_WEIGHT_DELTA_LEN) - 1) : 0] weight_delta_len,
    input [($clog2(`MAX_WEIGHT_NUM_LEN) - 1) : 0] weight_num_len,
    input [($clog2(`MAX_IDX_DELTA_LEN) - 1) : 0] idx_delta_len,
    input [($clog2(`INPUT_CHANNEL) - 1) : 0] IC_Num,
    input [($clog2(`OUTPUT_CHANNEL) - 1) : 0] OC_Num,

    // WB SRAM ports
    input [(`WEIGHT_SRAM_LEN - 1) : 0] WB_SRAM_in,
    input WB_SRAM_ready,
    output WB_SRAM_read,
    output [31 : 0] WB_SRAM_address,

    // SRAM start address for each WB memory
    input [31 : 0] WB_SRAM_idx_start_address,
    input [31 : 0] WB_SRAM_unique_start_address,
    input [31 : 0] WB_SRAM_repetition_start_address,

    // OB SRAM ports
    // For writing bias
    input [(`OUT_BIN_LEN - 1) : 0] OB_bias [(`OUTPUT_CHANNEL - 1) : 0],
    input [(`OUTPUT_CHANNEL - 1) : 0] OB_w_enable,
    input [(`OUTPUT_CHANNEL - 1) : 0] OB_r_enable,

    // For reading output data
    output [((`BIN_LEN * `OUTPUT_SRAM_LEN) - 1) : 0] OB_SRAM_out,
    input [($clog2(`OUTPUT_HEIGHT) - 1) : 0] OB_SRAM_r_out,
    input [($clog2(`OUTPUT_WIDTH) - 1) : 0] OB_SRAM_c_out,

    output finished
);

    // Module enables and finishes
    wire [(`INPUT_CHANNEL - 1) : 0] MPE_enable;
    wire [(`OUTPUT_CHANNEL - 1) : 0] APE_enable;
    wire total_finished;
    wire [(`INPUT_CHANNEL - 1) : 0] unique_buffer_enable;
    wire [(`INPUT_CHANNEL - 1) : 0] repetition_buffer_enable;
    wire [(`INPUT_CHANNEL - 1) : 0] idx_buffer_enable;
    wire [(`INPUT_CHANNEL - 1) : 0] in_line_start;

    // Module partial addresses for WB_SRAM access
    wire [31 : 0] unique_buffer_word_counter [(`INPUT_CHANNEL - 1) : 0];
    wire [31 : 0] repetition_buffer_word_counter [(`INPUT_CHANNEL - 1) : 0];
    wire [31 : 0] idx_buffer_word_counter [(`INPUT_CHANNEL - 1) : 0];

    // WB buffers read and ready ports
    wire [(`INPUT_CHANNEL - 1) : 0] unique_buffer_word_read;
    wire [(`INPUT_CHANNEL - 1) : 0] unique_buffer_word_ready;
    wire [(`INPUT_CHANNEL - 1) : 0] repetition_buffer_word_read;
    wire [(`INPUT_CHANNEL - 1) : 0] repetition_buffer_word_ready;
    wire [(`INPUT_CHANNEL - 1) : 0] idx_buffer_word_read;
    wire [(`INPUT_CHANNEL - 1) : 0] idx_buffer_word_ready;
    wire [(`INPUT_CHANNEL - 1) : 0] unique_buffer_busy;
    wire [(`INPUT_CHANNEL - 1) : 0] repetition_buffer_busy;
    wire [(`INPUT_CHANNEL - 1) : 0] repetition_buffer_filled;
    wire [(`INPUT_CHANNEL - 1) : 0] unique_buffer_filled;
    wire [(`INPUT_CHANNEL - 1) : 0] idx_buffer_filled;

    // Comes from unique weight buffer and shows if the weight is valid (stall untill it gets 1)
    wire [(`INPUT_CHANNEL - 1) : 0] weight_valid;
    // Comes from unique weight buffer and shows if the weight is absolute, otherwise it is delta 
    wire [(`INPUT_CHANNEL - 1) : 0] weight_abs;
    // Comes from repetition buffer and shows if a new weight is needed
    wire [(`INPUT_CHANNEL - 1) : 0] new_weight;

    // Absolute or delta weights
    wire [(`BIN_LEN - 1) : 0] weights [(`INPUT_CHANNEL - 1) : 0];

    // If 0, we have bubble
    wire [(`INPUT_CHANNEL - 1) : 0] is_index;

    // Shows if a line is finished
    wire [(`INPUT_CHANNEL - 1) : 0] line_finished;

    // Separated indices coming from index buffer
    wire [($clog2(`OUTPUT_CHANNEL) - 1) : 0] indices_output_channel [(`INPUT_CHANNEL - 1) : 0];
    wire [($clog2(`KERNEL_HEIGHT) - 1) : 0] indices_kernel_height [(`INPUT_CHANNEL - 1) : 0];
    wire [($clog2(`KERNEL_WIDTH) - 1) : 0] indices_kernel_width [(`INPUT_CHANNEL - 1) : 0];

    // Crossbar output shows if an APE must be enabled
    wire [(`OUTPUT_CHANNEL - 1) : 0] channel_en;

    // MPE outputs
    wire [(`OUT_BIN_LEN - 1) : 0] MPE_outputs [(`INPUT_CHANNEL - 1) : 0][(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0];
    wire [(`INPUT_CHANNEL - 1) : 0] MPE_out_ready;

    // APE inputs
    wire [(`OUT_BIN_LEN - 1) : 0] APE_inputs [(`OUTPUT_CHANNEL - 1) : 0][(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0];

    genvar i, j;

    for (i = 0; i < `INPUT_CHANNEL; i++) begin: MPE_generate
        MPE MPE_inst(
            .clock          (clock),
            .reset          (reset),

            .enable         (MPE_enable[i]),

            .inputs         (inputs[i]),

            .weight_val     (weights[i]),
            .weight_abs     (weight_abs[i]),

            .weight_height  (indices_kernel_height[i]), 
            .weight_width   (indices_kernel_width[i]),
            .stride         (stride),

            .output_vals    (MPE_outputs[i]),
            .out_ready      (MPE_out_ready[i])
        );

        PU_unique_weight_buffer PU_unique_weight_buffer_inst (
            .clock              (clock),
            .reset              (reset),
            .start              (in_line_start[i]),
            .enable             (unique_buffer_enable[i]),   // enable shows if a new weight is needed
            .finish             (line_finished[i]),

            .word_counter       (unique_buffer_word_counter[i]),
            .word_read          (unique_buffer_word_read[i]),
            .word_ready         (unique_buffer_word_ready[i]),

            .SRAM_in            (WB_SRAM_in),

            .weight_delta_len   (weight_delta_len),

            .weight_val         (weights[i]),
            .weight_valid       (weight_valid[i]),
            .weight_abs         (weight_abs[i]),
            .busy               (unique_buffer_busy[i]),
            .filled             (unique_buffer_filled[i])
        );

        PU_repetition_weight_buffer PU_repetition_weight_buffer (
            .clock              (clock),
            .reset              (reset),
            .start              (in_line_start[i]),
            .enable             (repetition_buffer_enable[i]),   // enable shows if there's not stall
            .finish             (line_finished[i]),

            .word_counter       (repetition_buffer_word_counter[i]),
            .word_read          (repetition_buffer_word_read[i]),
            .word_ready         (repetition_buffer_word_ready[i]),

            .SRAM_in            (WB_SRAM_in),

            .weight_num_len     (weight_num_len),

            .new_weight         (new_weight[i]),
            .busy               (repetition_buffer_busy[i]),
            .filled             (repetition_buffer_filled[i])
        );

        PU_idx_buffer PU_idx_buffer_inst (
            .clock              (clock),
            .reset              (reset),
            .start              (in_line_start[i]),
            .enable             (idx_buffer_enable[i]),   // enable shows if a new weight is needed
            .finish             (line_finished[i]),

            .word_counter       (idx_buffer_word_counter[i]),
            .word_read          (idx_buffer_word_read[i]),
            .word_ready         (idx_buffer_word_ready[i]),

            .SRAM_in            (WB_SRAM_in),

            .idx_delta_len      (idx_delta_len),

            .oc_val             (indices_output_channel[i]),
            .kr_val             (indices_kernel_height[i]),
            .kc_val             (indices_kernel_width[i]),
            .index              (is_index[i]),
            .finished           (line_finished[i]),
            .filled             (idx_buffer_filled[i])
        );

        PU_in_line_controller PU_in_line_controller_inst (
            .clock                      (clock),
            .reset                      (reset),
            .start                      (in_line_start[i]),

            // MPE signals
            .MPE_enable                 (MPE_enable[i]),
            .MPE_out_ready              (MPE_out_ready[i]),

            // Unique weight buffer signals
            .unique_buffer_enable       (unique_buffer_enable[i]),
            .unique_buffer_busy         (unique_buffer_busy[i]),
            .weight_valid               (weight_valid[i]),
            .unique_buffer_filled       (unique_buffer_filled[i]),

            // Repetition buffer signals
            .repetition_buffer_enable   (repetition_buffer_enable[i]),
            .repetition_buffer_busy     (repetition_buffer_busy[i]),
            .new_weight                 (new_weight[i]),
            .repetition_buffer_filled   (repetition_buffer_filled[i]),

            // Idx buffer signals
            .idx_buffer_enable          (idx_buffer_enable[i]),
            .is_index                   (is_index[i]),
            .finished                   (line_finished[i]),
            .idx_buffer_filled          (idx_buffer_filled[i])
        );
    end

    crossbar crossbar_inst(
        .is_index(is_index),
        .indices_output_channel(indices_output_channel),

        .MPE_outputs(MPE_outputs),

        .APE_inputs(APE_inputs),
        .channel_en(channel_en)
    );


    for (j = 0; j < `OUTPUT_CHANNEL; j++) begin: APE_generate
        APE APE_inst(
            .clock(clock),
            .reset(reset),

            .enable(APE_enable[j]),       // shows if we don't have stall
            .finish(total_finished),       // shows if indices are finished

            .AF_type(AF_type),
            .Pool_type(Pool_type),
            .Pool_stride(Pool_stride),
            .Pool_kernel_size(Pool_kernel_size),


            .bias(OB_bias[j]),     // biasses from SRAM
            .w_enable(OB_w_enable[j]),
            .r_enable(OB_r_enable[j]),

            .SRAM_out(OB_SRAM_out),        // accumulated values
            .SRAM_r_out(OB_SRAM_r_out),
            .SRAM_c_out(OB_SRAM_c_out),

            .MPE_vals(APE_inputs[j])     // multiplied values comming from MPEs
        );
    end

    PU_WB_SRAM_controller PU_WB_SRAM_controller_inst (
        .clock(clock),
        .reset(reset),

        .WB_SRAM_in(WB_SRAM_in),
        .WB_SRAM_ready(WB_SRAM_ready),
        .WB_SRAM_read(WB_SRAM_read),
        .WB_SRAM_address(WB_SRAM_address),

        // SRAM start address for each WB memory
        .WB_SRAM_idx_start_address(WB_SRAM_idx_start_address),
        .WB_SRAM_unique_start_address(WB_SRAM_unique_start_address),
        .WB_SRAM_repetition_start_address(WB_SRAM_repetition_start_address),

        // Module partial addresses for WB_SRAM access
        .unique_buffer_word_counter(unique_buffer_word_counter),
        .repetition_buffer_word_counter(repetition_buffer_word_counter),
        .idx_buffer_word_counter(idx_buffer_word_counter),

        // WB buffers read and ready ports
        .unique_buffer_word_read(unique_buffer_word_read),
        .unique_buffer_word_ready(unique_buffer_word_ready),
        .repetition_buffer_word_read(repetition_buffer_word_read),
        .repetition_buffer_word_ready(repetition_buffer_word_ready),
        .idx_buffer_word_read(idx_buffer_word_read),
        .idx_buffer_word_ready(idx_buffer_word_ready)
    );

    PU_controller PU_controller_inst(
        .clock(clock),
        .reset(reset),
        .start(start),

        // Tile configuration
        .IC_Num(IC_Num),
        .OC_Num(OC_Num),

        // Index buffer signal
        .line_finished(line_finished),

        // Input line signal
        .in_line_start(in_line_start),

        // APE control
        .APE_enable(APE_enable),
        
        // Final signal
        .total_finished(total_finished)

    );

    assign finished = total_finished;

endmodule