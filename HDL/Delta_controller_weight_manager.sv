`include "sys_defs.svh"

module Delta_controller_weight_manager(
	input clock,
	input reset,

	input start,
	input finish_cycle,

    input [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] OC_Num,
    input [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] IC_Num,
    input [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] ORC_Size,

	input [31 : 0] weight_start_address,

    // Weight buffer ports
    output reg [(`PU_NUM - 1) : 0] WB_SRAM_ready,
    input [(`PU_NUM - 1) : 0] WB_SRAM_read,
    input [31 : 0] WB_SRAM_address [(`PU_NUM - 1) : 0],

    // Weight SRAM ports
    output [31 : 0] Weight_SRAM_addr,
    output reg Weight_SRAM_w_en,
    output reg Weight_SRAM_r_en,
    input Weight_SRAM_d_ready,
    input Weight_SRAM_w_done,

	// DRAM access ports
	output reg DRAM_Read,
	output [31:0] DRAM_Address,
	input DRAM_DataReady
);

    reg [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] my_OC_Num;
    reg [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] my_IC_Num;
    reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] my_ORC_Size;

	reg [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] i_ch_first;
	reg [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] o_ch_first;
	reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] o_r_first;
	reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] o_c_first;
	reg idx_inc_en;

	reg [31 : 0] first_address;
	reg first_addr_inc_en;

	reg [($clog2(`PU_NUM) - 1) : 0] PU_itr;
	reg PU_itr_inc_en;

	reg WB_ready;

	always@(*) begin
		if(WB_ready == 1'b1) begin
			for (int i = 0; i < `PU_NUM; i++) begin
				if(i == PU_itr) begin
					WB_SRAM_ready[i] = 1'b1;
				end else begin
					WB_SRAM_ready[i] = 1'b0;
				end
			end
		end else begin
			WB_SRAM_ready = 0;
		end
	end

    always@(*) begin
    	if(OC_Num[2:0] == 3'b0) begin
    		my_OC_Num = OC_Num;
    	end else begin
    		my_OC_Num = {OC_Num[($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 3], 3'b0};
    	end
    	if(IC_Num[2:0] == 3'b0) begin
    		my_IC_Num = IC_Num;
    	end else begin
    		my_IC_Num = {IC_Num[($clog2(`MAX_INPUT_CHANNEL) - 1) : 3], 3'b0};
    	end
    	if(ORC_Size[2:0] == 3'b0) begin
    		my_ORC_Size = ORC_Size;
    	end else begin
    		my_ORC_Size = {ORC_Size[($clog2(`MAX_FEATURE_SIZE) - 1) : 3], 3'b0};
    	end
    end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			first_address = 0;
		end else if(first_addr_inc_en == 1'b1) begin		// increamented when delta cycle is finished
			first_address = first_address + (`PU_NUM * `INPUT_CHANNEL * `MAX_WEIGHT_LEN_BYTE);
		end
	end

	always@(posedge clock) begin
		if(reset) begin
			PU_itr = 0;
		end else if(PU_itr_inc_en) begin			// increamented each clock cycle to do arbitration
			PU_itr = PU_itr + 1;
		end
	end

	assign Weight_SRAM_addr = WB_SRAM_address[PU_itr] + (PU_itr << ($clog2(`INPUT_CHANNEL) + $clog2(`MAX_WEIGHT_LEN_BYTE))) + first_address;
	assign DRAM_Address = weight_start_address + Weight_SRAM_addr;

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			i_ch_first = 0;
			o_ch_first = 0;
			o_r_first = 0;
			o_c_first = 0;
		end else if(idx_inc_en == 1'b1) begin		// increamented when delta cycle is finished
			i_ch_first = i_ch_first + `INPUT_CHANNEL;
			if(i_ch_first == my_IC_Num) begin
				i_ch_first = 0;
				o_c_first = o_c_first + `OUTPUT_WIDTH;
				if(o_c_first == my_ORC_Size) begin
					o_c_first = 0;
					o_r_first = o_r_first + `OUTPUT_HEIGHT;
					if(o_r_first == my_ORC_Size) begin
						o_r_first = 0;
						o_ch_first = o_ch_first + (`OUTPUT_CHANNEL * `PU_NUM);
					end
				end
			end
		end
	end

	parameter WAIT_FOR_START = 3'd0,
			WAIT_FOR_QUERY = 3'd1,

			LD_DRAM = 3'd2,
			ST_SRAM = 3'd3,

			LD_SRAM = 3'd4,
			ST_BUFF = 3'd5,
			
			IDX_PLUS = 3'd6;

	reg [2:0] state, next_state;

    always@(*) begin
        next_state = WAIT_FOR_START;
        case (state)
            WAIT_FOR_START:
                if(start) begin
                    next_state = WAIT_FOR_QUERY;
                end else begin
                    next_state = WAIT_FOR_START;
                end

            WAIT_FOR_QUERY:
            	if(WB_SRAM_read[PU_itr] == 1'b1) begin
            		if(o_c_first == 0 && o_r_first == 0) begin
            			next_state = LD_DRAM;
            		end else begin
            			next_state = LD_SRAM;
            		end
            	end else begin
            		if(finish_cycle == 1'b1) begin
	            		next_state = IDX_PLUS;
	            	end else begin
	            		next_state = WAIT_FOR_QUERY;
	            	end
            	end

            LD_DRAM:
            	if(DRAM_DataReady == 1'b1) begin
            		next_state = ST_SRAM;
            	end else begin
            		next_state = LD_DRAM;
            	end

            ST_SRAM:
            	if(Weight_SRAM_w_done == 1'b1) begin
            		next_state = LD_SRAM;
            	end else begin
            		next_state = ST_SRAM;
            	end

            LD_SRAM:
            	if(Weight_SRAM_d_ready == 1'b1) begin
            		next_state = ST_BUFF;
            	end else begin
            		next_state = LD_SRAM;
            	end

            ST_BUFF: next_state = WAIT_FOR_QUERY;

            IDX_PLUS: next_state = WAIT_FOR_START;

            default: next_state = WAIT_FOR_START;
        endcase
    end

	always@(state) begin
		idx_inc_en = 1'b0;
		first_addr_inc_en = 1'b0;
		PU_itr_inc_en = 1'b0;
		DRAM_Read = 1'b0;
		Weight_SRAM_w_en = 1'b0;
		Weight_SRAM_r_en = 1'b0;
		WB_ready = 1'b0;
        case (state)

            WAIT_FOR_QUERY: begin
            	PU_itr_inc_en = 1'b1;
	        end

            LD_DRAM: begin
            	DRAM_Read = 1'b1;
            end

            ST_SRAM: begin
            	Weight_SRAM_w_en = 1'b1;
            end

            LD_SRAM: begin
            	Weight_SRAM_r_en = 1'b1;
            end

            ST_BUFF: begin
            	WB_ready = 1'b1;
            end
			
			IDX_PLUS: begin
				idx_inc_en = 1'b1;
				first_addr_inc_en = 1'b1;
			end
            
            default: begin
				idx_inc_en = 1'b0;
				first_addr_inc_en = 1'b0;
				PU_itr_inc_en = 1'b0;
				DRAM_Read = 1'b0;
				Weight_SRAM_w_en = 1'b0;
				Weight_SRAM_r_en = 1'b0;
				WB_ready = 1'b0;
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