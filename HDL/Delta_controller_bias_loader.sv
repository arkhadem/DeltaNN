`include "sys_defs.svh"

module Delta_controller_bias_loader(
	input clock,
	input reset,
	input start,

	input [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] OC_Num,
    input [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] ORC_Size,

    input [31 : 0] bias_start_address,

    // PU signals for writing bias data
    output reg [(`OUT_BIN_LEN - 1) : 0] OB_bias [(`PU_NUM - 1) : 0][(`OUTPUT_CHANNEL - 1) : 0],
    output reg [(`OUTPUT_CHANNEL - 1) : 0] OB_w_enable [(`PU_NUM - 1) : 0],

    // DRAM access ports
	output reg DRAM_Read,
	output reg [31:0] DRAM_Address,
	input [31:0] DRAM_ReadData,
	input DRAM_DataReady,

    output reg finished
);

	reg [(`BIN_LEN - 1) : 0] my_bias [(`PU_NUM - 1) : 0][(`OUTPUT_CHANNEL - 1) : 0];
	reg bias_ld_en;

	reg [($clog2(`OUTPUT_HEIGHT) - 1) : 0] Output_R;
	reg [($clog2(`OUTPUT_WIDTH) - 1) : 0] Output_C;
	reg out_plus_en;

	reg [($clog2(`PU_NUM) - 1) : 0] my_PU_num;
	reg PU_plus_en;

	reg OB_Load_en;

	always@(*) begin
		for (int i = 0; i < `PU_NUM; i++) begin
			OB_w_enable[i] = OB_Load_en;
			for (int j = 0; j < `OUTPUT_CHANNEL; j++) begin
				if(OB_Load_en == 1'b1) begin
					OB_bias[i][j] = {8'b0, my_bias[i][j]};
				end else begin
					OB_bias[i][j] = 0;
				end			
			end
		end
	end

	always@(posedge clock) begin
		if(reset) begin
			for (int i = 0; i < `PU_NUM; i++) begin
				for (int j = 0; j < `OUTPUT_CHANNEL; j++) begin
					my_bias[i][j] = 0;
				end
			end
		end else if(bias_ld_en) begin
			for (int i = 0; i < 4; i++) begin
				my_bias[my_PU_num][i] = DRAM_ReadData[(i * `BIN_LEN) +: `BIN_LEN];
			end
		end
	end

	always@(posedge clock) begin
		if(reset) begin
			my_PU_num = 0;
			DRAM_Address = bias_start_address;
		end else if(PU_plus_en) begin
			DRAM_Address = DRAM_Address + 4;
			if(my_PU_num == `PU_NUM) begin
				my_PU_num = 0;
			end else begin
				my_PU_num = my_PU_num + 1;
			end
		end
	end

	always@(posedge clock) begin
		if(reset) begin
			Output_R = 0;
			Output_C = 0;
		end else if(out_plus_en) begin
			if(Output_C >= ORC_Size) begin
				Output_C = 0;
				if(Output_R >= ORC_Size) begin
					Output_R = 0;
				end else begin
					Output_R = Output_R + `OUTPUT_WIDTH;
				end
			end else begin
				Output_C = Output_C + `OUTPUT_WIDTH;
			end
		end
	end

	parameter WAIT_FOR_START = 3'd0,
			PU_CHECK = 3'd1,
			LD_BIAS = 3'd2,
			WAIT_FOR_LD = 3'd3,
			ST_BIAS = 3'd4,
			PU_PLUS = 3'd5,
			PU_ST = 3'd6,
			OUTPUT_PLUS = 3'd7;

	reg [2:0] state, next_state;

    always@(*) begin
        next_state = WAIT_FOR_START;
        case (state)
            WAIT_FOR_START:
                if(start) begin
                    if(Output_R == 0 && Output_C == 0) begin
                    	next_state = PU_CHECK;
                    end else begin
                    	next_state = PU_ST;
                    end
                end else begin
                    next_state = WAIT_FOR_START;
                end

            PU_CHECK:
            	if(my_PU_num == `PU_NUM) begin
            		next_state = PU_ST;
            	end else begin
            		next_state = LD_BIAS;
            	end

            LD_BIAS: next_state = WAIT_FOR_LD;

            WAIT_FOR_LD:
            	if(DRAM_DataReady == 1'b1) begin
            		next_state = ST_BIAS;
            	end else begin
            		next_state = WAIT_FOR_LD;
            	end

            ST_BIAS: next_state = PU_PLUS;

            PU_PLUS: next_state = PU_CHECK;

            PU_ST: next_state = OUTPUT_PLUS;

            OUTPUT_PLUS: next_state = WAIT_FOR_START;

            default: next_state = WAIT_FOR_START;
        endcase
    end

	always@(*) begin
		finished = 1'b0;
		bias_ld_en = 1'b0;
		out_plus_en = 1'b0;
		PU_plus_en = 1'b0;
		OB_Load_en = 1'b0;
		DRAM_Read = 1'b0;
        case (state)

            LD_BIAS: begin
				DRAM_Read = 1'b1;
            end

            WAIT_FOR_LD: begin
            	DRAM_Read = 1'b1;
	        end

            ST_BIAS: begin
            	bias_ld_en = 1'b1;
            end

            PU_PLUS: begin
            	PU_plus_en = 1'b1;
            end

            PU_ST: begin
            	OB_Load_en = 1'b1;
            end

            OUTPUT_PLUS: begin
            	out_plus_en = 1'b1;
            	finished = 1'b1;
            end

            default: begin
				finished = 1'b0;
				bias_ld_en = 1'b0;
				out_plus_en = 1'b0;
				PU_plus_en = 1'b0;
				OB_Load_en = 1'b0;
				DRAM_Read = 1'b0;
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