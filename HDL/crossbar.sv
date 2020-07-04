`include "sys_defs.svh"

module crossbar(
    input [(`INPUT_CHANNEL - 1) : 0] is_index,
    input [($clog2(`OUTPUT_CHANNEL) - 1) : 0] indices_output_channel [(`INPUT_CHANNEL - 1) : 0],

	input [(`OUT_BIN_LEN - 1) : 0] MPE_outputs [(`INPUT_CHANNEL - 1) : 0][(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],

    output [(`OUT_BIN_LEN - 1) : 0] APE_inputs [(`OUTPUT_CHANNEL - 1) : 0][(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],
    output reg [(`OUTPUT_CHANNEL - 1) : 0] channel_en
);

	genvar i, j;

	genvar r, c;

    for (i = 0; i < `INPUT_CHANNEL; i++) begin: MPE_generate
	    for (j = 0; j < `OUTPUT_CHANNEL; j++) begin: APE_generate
	    	for (r = 0; r < `OUTPUT_HEIGHT; r++) begin: row_generate
	    		for (c = 0; c < `OUTPUT_WIDTH; c++) begin: column_generate
					assign APE_inputs[j][r][c] = (is_index[i] == 1'b1 && indices_output_channel[i] == j) ? MPE_outputs[i][r][c] : `OUT_BIN_LEN'bz;
	    		end
	    	end
	    end
    end

    always@(*) begin
    	for (int oc_itr = 0; oc_itr < `OUTPUT_CHANNEL; oc_itr++) begin
    		channel_en[oc_itr] = 0;
	    	for (int ic_itr = 0; ic_itr < `INPUT_CHANNEL; ic_itr++) begin
	    		if(is_index[ic_itr] == 1'b1 && indices_output_channel[ic_itr] == oc_itr)
		    		channel_en[oc_itr] = 1;
	    	end
	    end
    end

endmodule