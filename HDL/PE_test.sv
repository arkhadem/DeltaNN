`include "sys_defs.svh"

module PE_test();

    reg clock;
    reg reset;

    reg enable;

    reg [(`BIN_LEN - 1) : 0] input_val;

    reg [(`INPUT_WIDTH_LOG - 1) : 0] input_width_index;
    reg [(`INPUT_HEIGHT_LOG - 1) : 0] input_height_index;

    reg [(`BIN_LEN - 1) : 0] weight_val;
    reg [(`DELTA_LEN - 1) : 0] delta_vals [(`DELTA_NUM - 1) : 0];
    reg [(`DELTA_SIM_LEN - 1) : 0] delta_sims [(`DELTA_NUM - 1) : 0];

    reg [(`INDEX_WIDTH - 1) : 0] index_vals [(`INDEX_NUM - 1) : 0];

    wire w_en;
    wire [(`OUTPUT_CHANNEL_LOG - 1) : 0] w_channel_index;
    wire [(`OUTPUT_WIDTH_LOG - 1) : 0] w_height_index;
    wire [(`OUTPUT_HEIGHT_LOG - 1) : 0] w_width_index;
    wire [(`OUT_BIN_LEN - 1) : 0] w_val;

    wire done;

    reg [(`BIN_LEN-1):0] weights [(`OUTPUT_CHANNEL-1):0][(`KERNEL_HEIGHT-1):0][(`KERNEL_WIDTH-1):0];
    reg [(`BIN_LEN-1):0] one_dim_weights [(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];
    reg [(`OUTPUT_CHANNEL_LOG-1):0] output_channel_index [(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];
    reg [(`KERNEL_HEIGHT_LOG-1):0] kernel_height_index [(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];
    reg [(`KERNEL_WIDTH_LOG-1):0] kernel_width_index [(`OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1):0];

    integer last_index_num, rand_num;

    processing_element PE(
        .clock(clock),
        .reset(reset),

        .enable(enable),

        .input_val(input_val),

        .input_width_index(input_width_index),
        .input_height_index(input_height_index),

        .weight_val(weight_val),
        .delta_vals(delta_vals),
        .delta_sims(delta_sims),

        .index_vals(index_vals),

        .w_en(w_en),
        .w_channel_index(w_channel_index),
        .w_height_index(w_height_index),
        .w_width_index(w_width_index),
        .w_val(w_val),

        .done(done)
    );

    task weight_sort;
        integer largest_index;
        integer weight_tmp;
        integer output_channel_index_temp;
        integer height_index_temp;
        integer width_index_temp;
        for(int i = 0; i < `OUTPUT_CHANNEL; i++) begin
            for(int j = 0; j < `KERNEL_HEIGHT; j++) begin
                for(int k = 0; k < `KERNEL_WIDTH; k++) begin
                    one_dim_weights[i*`KERNEL_HEIGHT*`KERNEL_WIDTH + j*`KERNEL_WIDTH + k] = weights[i][j][k];
                    output_channel_index[i*`KERNEL_HEIGHT*`KERNEL_WIDTH + j*`KERNEL_WIDTH + k] = i;
                    kernel_height_index[i*`KERNEL_HEIGHT*`KERNEL_WIDTH + j*`KERNEL_WIDTH + k] = j;
                    kernel_width_index[i*`KERNEL_HEIGHT*`KERNEL_WIDTH + j*`KERNEL_WIDTH + k] = k;
                end
            end
        end
        for(int i = `OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH-1; i >= 0 ; i--) begin
            largest_index = 0;
            for(int j = 0; j <= i ; j++) begin
                if(one_dim_weights[j] > one_dim_weights[largest_index]) begin
                    largest_index = j;
                end
            end
            weight_tmp = one_dim_weights[largest_index];
            output_channel_index_temp = output_channel_index[largest_index];
            height_index_temp = kernel_height_index[largest_index];
            width_index_temp = kernel_width_index[largest_index];

            one_dim_weights[largest_index] = one_dim_weights[i];
            output_channel_index[largest_index] = output_channel_index[i];
            kernel_height_index[largest_index] = kernel_height_index[i];
            kernel_width_index[largest_index] = kernel_width_index[i];

            one_dim_weights[i] = weight_tmp;
            output_channel_index[i] = output_channel_index_temp;
            kernel_height_index[i] = height_index_temp;
            kernel_width_index[i] = width_index_temp;
        end
    endtask

    task delta_process;
        integer last_index_num;
        last_index_num = 0;
        delta_sims[0] = 1;
        delta_vals[0] = $clog2(one_dim_weights[1] - one_dim_weights[0]);
        for(int i = 2; i < `OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH; i++) begin
            if(one_dim_weights[i] == one_dim_weights[i-1]) begin
                delta_sims[last_index_num] = delta_sims[last_index_num] + 1;
            end else begin
                last_index_num = last_index_num + 1;
                delta_sims[last_index_num] = 1;
                delta_vals[last_index_num] = $clog2(one_dim_weights[i] - one_dim_weights[i-1]);
            end
        end
    endtask

    task random_index_producer;
        integer last_index_num;
        integer rand_num;
        last_index_num = 0;
        rand_num = 0;
        for(int i = 0; i < `OUTPUT_CHANNEL; i++) begin
            for(int j = 0; j < `KERNEL_HEIGHT; j++) begin
                for(int k = 0; k < `KERNEL_WIDTH; k++) begin
                    rand_num = $urandom() % 2;
                    if(rand_num) begin
                        rand_num = $urandom() % 10;
                        index_vals[last_index_num][(`INDEX_WIDTH - 2) : 0] = rand_num;
                        index_vals[last_index_num][`INDEX_WIDTH - 1] = 1'b1;
                        last_index_num = last_index_num + 1;
                    end
                    index_vals[last_index_num][(`OUTPUT_CHANNEL_LOG+`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG-1) : `KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG] = output_channel_index[i*`KERNEL_HEIGHT*`KERNEL_WIDTH + j*`KERNEL_WIDTH + k];
                    index_vals[last_index_num][(`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG-1) : `KERNEL_WIDTH_LOG] = kernel_height_index[i*`KERNEL_HEIGHT*`KERNEL_WIDTH + j*`KERNEL_WIDTH + k];
                    index_vals[last_index_num][(`KERNEL_WIDTH_LOG-1) : 0] = kernel_width_index[i*`KERNEL_HEIGHT*`KERNEL_WIDTH + j*`KERNEL_WIDTH + k];
                    index_vals[last_index_num][`INDEX_WIDTH - 1] = 1'b0;
                    last_index_num = last_index_num + 1;
                end
            end
        end
        index_vals[last_index_num] = 0;
        index_vals[last_index_num][`INDEX_WIDTH - 1] = 1'b1;
        last_index_num = last_index_num + 1;
    endtask

    task random_weight_producer;
        for(int i = 0; i < `OUTPUT_CHANNEL; i++) begin
            for(int j = 0; j < `KERNEL_HEIGHT; j++) begin
                for(int k = 0; k < `KERNEL_WIDTH; k++) begin
                    weights[i][j][k] = ($urandom() % (2**`BIN_LEN)) + 1;
                end
            end
        end
        weights[$urandom() % `OUTPUT_CHANNEL][$urandom() % `KERNEL_HEIGHT][$urandom() % `KERNEL_WIDTH] = 0;
    endtask

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 0;
        enable = 0;
        input_val = 0;
        input_width_index = 0;
        input_height_index = 0;
        weight_val = 0;
        for(int i = 0; i < `DELTA_NUM; i++) begin
            delta_vals[i] = 0;
            delta_sims[i] = 0;
        end
        for(int i = 0; i < `INDEX_NUM; i++) begin
            index_vals[i] = 0;
        end
        @(negedge clock);
        reset = 1;
        @(negedge clock);
        reset = 0;
        @(negedge clock);

        random_weight_producer();
        weight_sort();
        delta_process();
        random_index_producer();

        weight_val = one_dim_weights[0];
        input_val = 1;
        input_width_index = 1;
        input_height_index = 1;

        @(negedge clock);

        enable = 1;

        for(int i = 0; i < `OUTPUT_CHANNEL; i++) begin
            for(int j = 0; j < `KERNEL_HEIGHT; j++) begin
                for(int k = 0; k < `KERNEL_WIDTH; k++) begin
                    $display("waiting for write enable");
                    @(posedge w_en);
                    $display("write enable received");
                end
            end
        end

        $display("waiting for done flag");
        @(posedge done);
        enable = 0;
        $display("done received");
        $finish;
    end

endmodule
