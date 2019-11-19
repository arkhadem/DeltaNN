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
        input_val = 1;
        input_width_index = 1;
        input_height_index = 1;
        weight_val = 0;

        delta_vals[0] = 0;
        delta_sims[0] = 2;

        delta_vals[1] = 0;
        delta_sims[1] = 2;

        delta_vals[2] = 0;
        delta_sims[2] = 4;

        delta_vals[3] = 0;
        delta_sims[3] = 1;

        delta_vals[4] = 0;
        delta_sims[4] = 3;

        delta_vals[5] = 0;
        delta_sims[5] = 2;

        delta_vals[6] = 0;
        delta_sims[6] = 1;

        index_vals[0] = {1'b0, 2'd3, 1'd0, 1'd1};
        index_vals[1] = {1'b1, 4'd1};
        index_vals[2] = {1'b0, 2'd1, 1'd0, 1'd0};
        index_vals[3] = {1'b0, 2'd2, 1'd1, 1'd0};
        index_vals[4] = {1'b1, 4'd2};
        index_vals[5] = {1'b0, 2'd0, 1'd0, 1'd1};
        index_vals[6] = {1'b0, 2'd3, 1'd1, 1'd0};
        index_vals[7] = {1'b1, 4'd1};
        index_vals[8] = {1'b0, 2'd1, 1'd1, 1'd0};
        index_vals[9] = {1'b1, 4'd1};
        index_vals[10] = {1'b0, 2'd2, 1'd0, 1'd1};
        index_vals[11] = {1'b1, 4'd3};
        index_vals[12] = {1'b0, 2'd0, 1'd0, 1'd0};
        index_vals[13] = {1'b0, 2'd2, 1'd1, 1'd1};
        index_vals[14] = {1'b1, 4'd2};
        index_vals[15] = {1'b0, 2'd1, 1'd0, 1'd1};
        index_vals[16] = {1'b1, 4'd3};
        index_vals[17] = {1'b0, 2'd0, 1'd1, 1'd0};
        index_vals[18] = {1'b0, 2'd3, 1'd1, 1'd1};
        index_vals[19] = {1'b1, 4'd2};
        index_vals[20] = {1'b0, 2'd1, 1'd1, 1'd1};
        index_vals[21] = {1'b0, 2'd0, 1'd1, 1'd1};
        index_vals[22] = {1'b1, 4'd5};
        index_vals[23] = {1'b0, 2'd2, 1'd0, 1'd0};
        index_vals[24] = {1'b0, 2'd3, 1'd0, 1'd0};
        index_vals[25] = {1'b1, 4'd0};

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
