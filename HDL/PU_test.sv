`include "sys_defs.svh"

module PU_test();

    reg clock;
    reg reset;
    reg enable;

    //inputs
    reg [(`BIN_LEN - 1) : 0] input_vals [`INPUT_CHANNEL - 1 : 0][`INPUT_HEIGHT - 1 : 0][`INPUT_WIDTH - 1 : 0];

    //weights
    reg  [(`BIN_LEN - 1) : 0] weight_vals [`INPUT_CHANNEL - 1 : 0];
    reg [(`DELTA_LEN - 1) : 0] delta_vals [`INPUT_CHANNEL - 1 : 0][(`DELTA_NUM - 1) : 0];
    reg [(`DELTA_SIM_LEN - 1) : 0] delta_sims [`INPUT_CHANNEL - 1 : 0][(`DELTA_NUM - 1) : 0];

    //indices
    reg [(`INDEX_WIDTH - 1) : 0] index_vals [(`INPUT_CHANNEL - 1) : 0][(`INDEX_NUM - 1) : 0];

    //outputs
    wire [(`OUT_BIN_LEN - 1) : 0] output_vals [`OUTPUT_CHANNEL - 1 : 0][`OUTPUT_HEIGHT - 1 : 0][`OUTPUT_WIDTH - 1 : 0];

    wire done;

    processing_unit UUT(
        .clock(clock),
        .reset(reset),
        .enable(enable),

        .input_vals(input_vals),

        .weight_vals(weight_vals),

        .delta_vals(delta_vals),
        .delta_sims(delta_sims),


        .index_vals(index_vals),

        .output_vals(output_vals),

        .done(done)
    );

    reg [(`BIN_LEN-1):0] weights [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL-1):0][(`KERNEL_HEIGHT-1):0][(`KERNEL_WIDTH-1):0];
    reg [(`BIN_LEN-1):0] one_dim_weights [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];
    reg [(`OUTPUT_CHANNEL_LOG-1):0] output_channel_index [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];
    reg [(`KERNEL_HEIGHT_LOG-1):0] kernel_height_index [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];
    reg [(`KERNEL_WIDTH_LOG-1):0] kernel_width_index [(`INPUT_CHANNEL-1):0][(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];


    task weight_sort;
        integer largest_index;
        integer weight_tmp;
        integer output_channel_index_temp;
        integer height_index_temp;
        integer width_index_temp;
        for(int i = 0; i < `INPUT_CHANNEL; i++) begin
            for(int j = 0; j < `OUTPUT_CHANNEL; j++) begin
                for(int k = 0; k < `KERNEL_HEIGHT; k++) begin
                    for(int l = 0; l < `KERNEL_WIDTH; l++) begin
                        one_dim_weights[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l] = weights[i][j][k][l];
                        output_channel_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l] = j;
                        kernel_height_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l] = k;
                        kernel_width_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l] = l;
                    end
                end
            end
            for(int j = `OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1; j >= 0 ; j--) begin
                largest_index = 0;
                for(int k = 0; k <= j ; k++) begin
                    if(one_dim_weights[i][k] > one_dim_weights[i][largest_index]) begin
                        largest_index = k;
                    end
                end
                weight_tmp = one_dim_weights[i][largest_index];
                output_channel_index_temp = output_channel_index[i][largest_index];
                height_index_temp = kernel_height_index[i][largest_index];
                width_index_temp = kernel_width_index[i][largest_index];

                one_dim_weights[i][largest_index] = one_dim_weights[i][j];
                output_channel_index[i][largest_index] = output_channel_index[i][j];
                kernel_height_index[i][largest_index] = kernel_height_index[i][j];
                kernel_width_index[i][largest_index] = kernel_width_index[i][j];

                one_dim_weights[i][j] = weight_tmp;
                output_channel_index[i][j] = output_channel_index_temp;
                kernel_height_index[i][j] = height_index_temp;
                kernel_width_index[i][j] = width_index_temp;
            end
        end
    endtask

    task delta_process;
        integer last_index_num;
        for(int i = 0; i < `INPUT_CHANNEL; i++) begin
            last_index_num = 0;
            delta_sims[i][0] = 1;
            delta_vals[i][0] = $clog2(one_dim_weights[i][1] - one_dim_weights[i][0]);
            for(int j = 2; j < `OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH; j++) begin
                if(one_dim_weights[i][j] == one_dim_weights[i][j-1]) begin
                    delta_sims[i][last_index_num] = delta_sims[i][last_index_num] + 1;
                end else begin
                    last_index_num = last_index_num + 1;
                    delta_sims[i][last_index_num] = 1;
                    delta_vals[i][last_index_num] = $clog2(one_dim_weights[i][j] - one_dim_weights[i][j-1]);
                end
            end
        end
    endtask

    task random_index_producer;
        integer last_index_num;
        integer rand_num;
        for(int i = 0; i < `INPUT_CHANNEL; i++) begin
            last_index_num = 0;
            rand_num = 0;
            for(int j = 0; j < `OUTPUT_CHANNEL; j++) begin
                for(int k = 0; k < `KERNEL_HEIGHT; k++) begin
                    for(int l = 0; l < `KERNEL_WIDTH; l++) begin
                        rand_num = $urandom() % 2;
                        if(rand_num) begin
                            rand_num = $urandom() % 10 + 1;
                            index_vals[i][last_index_num][(`INDEX_WIDTH - 2) : 0] = rand_num;
                            index_vals[i][last_index_num][`INDEX_WIDTH - 1] = 1'b1;
                            last_index_num = last_index_num + 1;
                        end
                        index_vals[i][last_index_num][(`OUTPUT_CHANNEL_LOG+`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG-1) : `KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG] = output_channel_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l];
                        index_vals[i][last_index_num][(`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG-1) : `KERNEL_WIDTH_LOG] = kernel_height_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l];
                        index_vals[i][last_index_num][(`KERNEL_WIDTH_LOG-1) : 0] = kernel_width_index[i][j*`KERNEL_HEIGHT*`KERNEL_WIDTH + k*`KERNEL_WIDTH + l];
                        index_vals[i][last_index_num][`INDEX_WIDTH - 1] = 1'b0;
                        last_index_num = last_index_num + 1;
                    end
                end
            end
            index_vals[i][last_index_num] = 0;
            index_vals[i][last_index_num][`INDEX_WIDTH - 1] = 1'b1;
            last_index_num = last_index_num + 1;
        end
    endtask

    task random_weight_input_producer;
        for(int i = 0; i < `INPUT_CHANNEL; i++) begin
            for(int j = 0; j < `OUTPUT_CHANNEL; j++) begin
                for(int k = 0; k < `KERNEL_HEIGHT; k++) begin
                    for(int l = 0; l < `KERNEL_WIDTH; l++) begin
                        weights[i][j][k][l] = ($urandom() % (2**`BIN_LEN)) + 1;
                    end
                end
            end
            weights[i][$urandom() % `OUTPUT_CHANNEL][$urandom() % `KERNEL_HEIGHT][$urandom() % `KERNEL_WIDTH] = 0;

            for(int j = 0; j < `INPUT_HEIGHT; j++) begin
                for(int k = 0; k < `INPUT_WIDTH; k++) begin
                    input_vals[i][j][k] = ($urandom() % (2**`BIN_LEN));
                end
            end

        end
    endtask

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 0;
        enable = 0;
        for(int i = 0; i < `INPUT_CHANNEL; i++) begin
            for(int j = 0; j < `INPUT_HEIGHT; j++) begin
                for(int k = 0; k < `INPUT_WIDTH; k++) begin
                    input_vals[i][j][k] = 0;
                end
            end
            weight_vals[i] = 0;
        end
        for(int i = 0; i < `INPUT_CHANNEL; i++) begin
            for(int j = 0; j < `DELTA_NUM; j++) begin
                delta_vals[i][j] = 0;
                delta_sims[i][j] = 0;
            end
            for(int j = 0; j < `INDEX_NUM; j++) begin
                index_vals[i][j] = 0;
            end
        end
        @(negedge clock);
        reset = 1;
        @(negedge clock);
        reset = 0;
        @(negedge clock);

        random_weight_input_producer();
        weight_sort();
        delta_process();
        random_index_producer();

        for(int i = 0; i < `INPUT_CHANNEL; i++) begin
            weight_vals[i] = one_dim_weights[i][0];
        end

        @(negedge clock);

        enable = 1;

        $display("waiting for done flag");
        @(posedge done);
        enable = 0;
        $display("done received");
        @(posedge clock);
        $finish;

    end

endmodule
