`include "sys_defs.svh"

module PU_test();

    reg clock;
    reg reset;
    reg start;

    // //inputs
    reg [(`BIN_LEN - 1) : 0] input_vals [`INPUT_CHANNEL - 1 : 0][`INPUT_HEIGHT - 1 : 0][`INPUT_WIDTH - 1 : 0];

    // //weights
    // reg [(`BIN_LEN - 1) : 0] weight_vals [`INPUT_CHANNEL - 1 : 0];
    // reg [(`DELTA_LEN - 1) : 0] unique_weights [`INPUT_CHANNEL - 1 : 0][(`DELTA_NUM - 1) : 0];
    // reg [(`DELTA_SIM_LEN - 1) : 0] unique_repetition [`INPUT_CHANNEL - 1 : 0][(`DELTA_NUM - 1) : 0];

    // //indices
    // reg [(`INDEX_WIDTH - 1) : 0] index_vals [(`INPUT_CHANNEL - 1) : 0][(`INDEX_NUM - 1) : 0];

    // //outputs
    // wire [(`OUT_BIN_LEN - 1) : 0] output_vals [`OUTPUT_CHANNEL - 1 : 0][`OUTPUT_HEIGHT - 1 : 0][`OUTPUT_WIDTH - 1 : 0];

    wire done;

    wire [2 : 0] stride;
    wire [2 : 0] AF_type;
    wire [2 : 0] Pool_type;
    wire [2 : 0] Pool_stride;
    wire [2 : 0] Pool_kernel_size;

    wire [($clog2(`MAX_WEIGHT_DELTA_LEN) - 1) : 0] weight_delta_len;
    wire [($clog2(`MAX_WEIGHT_NUM_LEN) - 1) : 0] weight_num_len;
    wire [($clog2(`MAX_IDX_DELTA_LEN) - 1) : 0] idx_delta_len;
    wire [($clog2(`INPUT_CHANNEL) - 1) : 0] IC_Num;
    wire [($clog2(`OUTPUT_CHANNEL) - 1) : 0] OC_Num;

    wire [31 : 0] WB_SRAM_idx_start_address;
    wire [31 : 0] WB_SRAM_unique_start_address;
    wire [31 : 0] WB_SRAM_repetition_start_address;

    reg [(`WEIGHT_SRAM_LEN - 1) : 0] WB_SRAM_in;
    reg WB_SRAM_ready;
    wire WB_SRAM_read;
    wire [31 : 0] WB_SRAM_address;

    reg [((`OUT_BIN_LEN * `OUTPUT_SRAM_LEN) - 1) : 0] OB_SRAM_in;
    wire [((`OUT_BIN_LEN * `OUTPUT_SRAM_LEN) - 1) : 0] OB_SRAM_out;
    reg OB_w_enable;
    reg [($clog2(`OUTPUT_HEIGHT) - 1) : 0] OB_SRAM_r_in;
    reg [($clog2(`OUTPUT_WIDTH) - 1) : 0] OB_SRAM_c_in;
    reg [($clog2(`OUTPUT_HEIGHT) - 1) : 0] OB_SRAM_r_out;
    reg [($clog2(`OUTPUT_WIDTH) - 1) : 0] OB_SRAM_c_out;

    assign stride = 3'd1;
    assign AF_type = `AF_RELU;
    assign Pool_type = `POOL_MAX;
    assign Pool_stride = 3'd1;
    assign Pool_kernel_size = 3'd2;

    assign weight_delta_len = 2;
    assign weight_num_len = 5;
    assign idx_delta_len = 2;
    assign IC_Num = 4;
    assign OC_Num = 4;

    assign WB_SRAM_idx_start_address = 32'h0000_0000;
    assign WB_SRAM_unique_start_address = 32'h1000_0000;
    assign WB_SRAM_repetition_start_address = 32'h2000_0000;

    processing_unit UUT(
        .clock(clock),
        .reset(reset),
        .start(start),

        // NN configuration
        .inputs(input_vals),
        .stride(stride),
        .AF_type(AF_type),
        .Pool_type(Pool_type),
        .Pool_stride(Pool_stride),
        .Pool_kernel_size(Pool_kernel_size),

        .weight_delta_len(weight_delta_len),
        .weight_num_len(weight_num_len),
        .idx_delta_len(idx_delta_len),
        .IC_Num(IC_Num),
        .OC_Num(OC_Num),

        // WB SRAM ports
        .WB_SRAM_in(WB_SRAM_in),
        .WB_SRAM_ready(WB_SRAM_ready),
        .WB_SRAM_read(WB_SRAM_read),
        .WB_SRAM_address(WB_SRAM_address),

        // SRAM start address for each WB memory
        .WB_SRAM_idx_start_address(WB_SRAM_idx_start_address),
        .WB_SRAM_unique_start_address(WB_SRAM_unique_start_address),
        .WB_SRAM_repetition_start_address(WB_SRAM_repetition_start_address),

        // OB SRAM ports
        .OB_SRAM_in(OB_SRAM_in),
        .OB_SRAM_out(OB_SRAM_out),
        .OB_w_enable(OB_w_enable),
        .OB_SRAM_r_in(OB_SRAM_r_in),
        .OB_SRAM_c_in(OB_SRAM_c_in),
        .OB_SRAM_r_out(OB_SRAM_r_out),
        .OB_SRAM_c_out(OB_SRAM_c_out),

        .finished(done)
    );

    // reg [(`BIN_LEN-1):0] weights [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL-1):0][(`KERNEL_HEIGHT-1):0][(`KERNEL_WIDTH-1):0];
    // reg [(`BIN_LEN-1):0] one_dim_weights [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];
    // reg [($clog2(`OUTPUT_CHANNEL)-1):0] output_channel_index [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];
    // reg [($clog2(`KERNEL_HEIGHT)-1):0] kernel_height_index [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];
    // reg [($clog2(`KERNEL_WIDTH)-1):0] kernel_width_index [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];


    // task weight_sort;
    //     integer largest_index;
    //     integer weight_tmp;
    //     integer output_channel_index_temp;
    //     integer height_index_temp;
    //     integer width_index_temp;
    //     for(int i = 0; i < `INPUT_CHANNEL; i++) begin
    //         for(int j = 0; j < `OUTPUT_CHANNEL; j++) begin
    //             for(int k = 0; k < `KERNEL_HEIGHT; k++) begin
    //                 for(int l = 0; l < `KERNEL_WIDTH; l++) begin
    //                     one_dim_weights[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l] = weights[i][j][k][l];
    //                     output_channel_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l] = j;
    //                     kernel_height_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l] = k;
    //                     kernel_width_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l] = l;
    //                 end
    //             end
    //         end
    //         for(int j = `OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1; j >= 0 ; j--) begin
    //             largest_index = 0;
    //             for(int k = 0; k <= j ; k++) begin
    //                 if(one_dim_weights[i][k] > one_dim_weights[i][largest_index]) begin
    //                     largest_index = k;
    //                 end
    //             end
    //             weight_tmp = one_dim_weights[i][largest_index];
    //             output_channel_index_temp = output_channel_index[i][largest_index];
    //             height_index_temp = kernel_height_index[i][largest_index];
    //             width_index_temp = kernel_width_index[i][largest_index];

    //             one_dim_weights[i][largest_index] = one_dim_weights[i][j];
    //             output_channel_index[i][largest_index] = output_channel_index[i][j];
    //             kernel_height_index[i][largest_index] = kernel_height_index[i][j];
    //             kernel_width_index[i][largest_index] = kernel_width_index[i][j];

    //             one_dim_weights[i][j] = weight_tmp;
    //             output_channel_index[i][j] = output_channel_index_temp;
    //             kernel_height_index[i][j] = height_index_temp;
    //             kernel_width_index[i][j] = width_index_temp;
    //         end
    //     end
    // endtask

    // task delta_process;
    //     integer last_index_num;
    //     for(int i = 0; i < `INPUT_CHANNEL; i++) begin
    //         last_index_num = -1;
    //         last_unique = 0;
    //         for(int j = 0; j < `OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH; j++) begin
    //             if(one_dim_weights[i][j] == one_dim_weights[i][last_index_num]) begin
    //                 unique_repetition[i][last_index_num] = unique_repetition[i][last_index_num] + 1;
    //             end else begin
    //                 // a new weight is detected
                    
    //                 last_index_num = last_index_num + 1;
    //                 unique_repetition[i][last_index_num] = 1;
    //                 unique_weights[i][last_index_num] = $clog2(one_dim_weights[i][j] - one_dim_weights[i][j-1]);
    //             end
    //         end
    //     end
    // endtask

    // task random_index_producer;
    //     integer last_index_num;
    //     integer rand_num;
    //     for(int i = 0; i < `INPUT_CHANNEL; i++) begin
    //         last_index_num = 0;
    //         rand_num = 0;
    //         for(int j = 0; j < `OUTPUT_CHANNEL; j++) begin
    //             for(int k = 0; k < `KERNEL_HEIGHT; k++) begin
    //                 for(int l = 0; l < `KERNEL_WIDTH; l++) begin
    //                     rand_num = $urandom() % 2;
    //                     if(rand_num) begin
    //                         rand_num = $urandom() % 10 + 1;
    //                         index_vals[i][last_index_num][(`INDEX_WIDTH - 2) : 0] = rand_num;
    //                         index_vals[i][last_index_num][`INDEX_WIDTH - 1] = 1'b1;
    //                         last_index_num = last_index_num + 1;
    //                     end
    //                     index_vals[i][last_index_num][($clog2(`OUTPUT_CHANNEL)+$clog2(`KERNEL_HEIGHT)+$clog2(`KERNEL_WIDTH)-1) : $clog2(`KERNEL_HEIGHT)+$clog2(`KERNEL_WIDTH)] = output_channel_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l];
    //                     index_vals[i][last_index_num][($clog2(`KERNEL_HEIGHT)+$clog2(`KERNEL_WIDTH)-1) : $clog2(`KERNEL_WIDTH)] = kernel_height_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l];
    //                     index_vals[i][last_index_num][($clog2(`KERNEL_WIDTH)-1) : 0] = kernel_width_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l];
    //                     index_vals[i][last_index_num][`INDEX_WIDTH - 1] = 1'b0;
    //                     last_index_num = last_index_num + 1;
    //                 end
    //             end
    //         end
    //         index_vals[i][last_index_num] = 0;
    //         index_vals[i][last_index_num][`INDEX_WIDTH - 1] = 1'b1;
    //         last_index_num = last_index_num + 1;
    //     end
    // endtask

    // task random_weight_input_producer;
    //     for(int i = 0; i < `INPUT_CHANNEL; i++) begin
    //         for(int j = 0; j < `OUTPUT_CHANNEL; j++) begin
    //             for(int k = 0; k < `KERNEL_HEIGHT; k++) begin
    //                 for(int l = 0; l < `KERNEL_WIDTH; l++) begin
    //                     weights[i][j][k][l] = ($urandom() % (2**`BIN_LEN)) + 1;
    //                 end
    //             end
    //         end

    //         for(int j = 0; j < `INPUT_HEIGHT; j++) begin
    //             for(int k = 0; k < `INPUT_WIDTH; k++) begin
    //                 input_vals[i][j][k] = ($urandom() % (2**`BIN_LEN));
    //             end
    //         end

    //     end
    // endtask

    always begin
        #5;
        clock = ~clock;
    end

    // initial begin
    //     clock = 0;
    //     reset = 0;
    //     enable = 0;
    //     for(int i = 0; i < `INPUT_CHANNEL; i++) begin
    //         for(int j = 0; j < `INPUT_HEIGHT; j++) begin
    //             for(int k = 0; k < `INPUT_WIDTH; k++) begin
    //                 input_vals[i][j][k] = 0;
    //             end
    //         end
    //         weight_vals[i] = 0;
    //     end
    //     for(int i = 0; i < `INPUT_CHANNEL; i++) begin
    //         for(int j = 0; j < `DELTA_NUM; j++) begin
    //             unique_weights[i][j] = 0;
    //             unique_repetition[i][j] = 0;
    //         end
    //         for(int j = 0; j < `INDEX_NUM; j++) begin
    //             index_vals[i][j] = 0;
    //         end
    //     end
    //     @(negedge clock);
    //     reset = 1;
    //     @(negedge clock);
    //     reset = 0;
    //     @(negedge clock);

    //     random_weight_input_producer();
    //     weight_sort();
    //     delta_process();
    //     random_index_producer();

    //     for(int i = 0; i < `INPUT_CHANNEL; i++) begin
    //         weight_vals[i] = one_dim_weights[i][0];
    //     end

    //     @(negedge clock);

    //     enable = 1;

    //     $display("waiting for done flag");
    //     @(posedge done);
    //     enable = 0;
    //     $display("done received");
    //     @(posedge clock);
    //     $finish;

    // end

endmodule
