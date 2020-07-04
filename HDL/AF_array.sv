`include "sys_defs.svh"

module AF_array (
	input finish,
	input [(`OUT_BIN_LEN - 1) : 0] buffer_outputs [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0],
	input [1 : 0] AF_type,
	output reg [(`OUT_BIN_LEN - 1) : 0] AF_outputs [(`OUTPUT_HEIGHT - 1) : 0][(`OUTPUT_WIDTH - 1) : 0]
);

	always@(*) begin
		if(finish) begin
			for (int i = 0; i < `OUTPUT_HEIGHT; i++) begin
				for (int j = 0; j < `OUTPUT_WIDTH; j++) begin
					case (AF_type)
						`AF_NONE: AF_outputs[i][j] = buffer_outputs[i][j];
						`AF_RELU: AF_outputs[i][j] = (buffer_outputs[i][j][`OUT_BIN_LEN - 1] == 1) ? 0 : buffer_outputs[i][j];
						default : AF_outputs[i][j] = {`OUT_BIN_LEN{1'bz}};
					endcase
				end
			end
		end else begin
			for (int i = 0; i < `OUTPUT_HEIGHT; i++) begin
				for (int j = 0; j < `OUTPUT_WIDTH; j++) begin
					AF_outputs[i][j] = {`OUT_BIN_LEN{1'bz}};
				end
			end
		end
	end

endmodule