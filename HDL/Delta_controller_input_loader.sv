`include "sys_defs.svh"

module Delta_controller_input_loader(
	input clock,
	input reset,

	input start_SRAM_load,
	input start_buffer_load,

    input [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] IC_Num,
    input [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] RC_Size,

    input [2 : 0] stride,
    input [3 : 0] kernel_size,

    input [31 : 0] input_start_address,

    // DRAM access ports
	output reg DRAM_Read,
	output reg [31:0] DRAM_Address,
	input [31:0] DRAM_ReadData,
	input DRAM_DataReady,

	// Input SRAM access ports
    output [127 : 0] Input_SRAM_w_d,
    output reg [31 : 0] Input_SRAM_w_addr,
    output reg [31 : 0] Input_SRAM_r_addr,
    output reg Input_SRAM_w_en,
    output reg Input_SRAM_r_en,
    input Input_SRAM_d_ready,
    input Input_SRAM_w_done,

	// Input buffer access ports
    output [(`INPUT_CHANNEL - 1) : 0] IB_w_enable,
    output [($clog2(`INPUT_HEIGHT) - 1) : 0] IB_SRAM_r,
    output [($clog2(`INPUT_WIDTH) - 1) : 0] IB_SRAM_c,

    output reg finished
);

    reg [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] my_IC_Num;
    reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] my_RC_Size;

	reg [31 : 0] my_DRAM_Address;
	reg [31 : 0] my_Input_SRAM_w_addr;

    reg [127 : 0] SRAM_store;
    reg first_SRAM_store;
    reg second_SRAM_store;
    reg third_SRAM_store;
    reg fourth_SRAM_store;

    reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] T_input_size;

	reg [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] i_ch_1, i_ch_first;
	reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] i_r_1, i_r_first;
	reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] i_c_1, i_c_first;

	reg [($clog2(`INPUT_CHANNEL) - 1) : 0] i_ch_2;
	reg [($clog2(`INPUT_HEIGHT) - 1) : 0] i_r_2;
	reg [($clog2(`INPUT_WIDTH) - 1) : 0] i_c_2;

	reg [31 : 0] my_input_SRAM_start_address;
	reg [31 : 0] my_input_SRAM_add_address;

	reg i_DRAM_inc, i_SRAM_inc;
	reg first_inc_enable;
	reg add_inc_enable;
	reg add_inc_reset;
	reg IB_w_en;

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			my_input_SRAM_start_address = 0;
			i_ch_first = 0;
			i_r_first = 0;
			i_c_first = 0;
		end else if (first_inc_enable == 1'b1) begin
			if(i_c_first == my_RC_Size) begin
				i_c_first = 0;
				if(i_r_first == my_RC_Size) begin
					i_r_first = 0;
					i_ch_first = i_ch_first + `INPUT_CHANNEL;
					my_input_SRAM_start_address = my_input_SRAM_start_address + (my_RC_Size << 2) - my_RC_Size;// ((my_RC_Size * my_RC_Size) << 2) - (my_RC_Size * my_RC_Size);
				end else begin
					i_r_first = i_r_first + (stride << 3);
					my_input_SRAM_start_address = my_input_SRAM_start_address + ((stride - 1) << 3); // * my_RC_Size);
				end
			end else begin
				i_c_first = i_c_first + (stride << 3);
				my_input_SRAM_start_address = my_input_SRAM_start_address + (stride << 3);
			end
		end
	end

	always@(posedge clock) begin
		if(add_inc_reset == 1'b1 || reset == 1'b1) begin
			my_input_SRAM_add_address = 0;
			i_ch_2 = 0;
			i_r_2 = 0;
			i_c_2 = 0;			
		end else if(add_inc_enable == 1'b1) begin
			if(i_c_2 == T_input_size) begin
				i_c_2 = 0;
				if(i_r_2 == T_input_size) begin
					i_r_2 = 0;
					i_ch_2 = i_ch_2 + 1;
					my_input_SRAM_add_address = my_input_SRAM_add_address + my_RC_Size - T_input_size;// (my_RC_Size * my_RC_Size) - (T_input_size * T_input_size);
				end else begin
					i_r_2 = i_r_2 + 1;
					my_input_SRAM_add_address = my_input_SRAM_add_address + my_RC_Size - T_input_size;
				end
			end else begin
				i_c_2 = i_c_2 + 8;
				my_input_SRAM_add_address = my_input_SRAM_add_address + 8;
			end
		end
	end

	assign IB_w_enable[0] = ((IB_w_en == 1'b1) && (i_ch_2 == 0)) ? 1'b1 : 1'b0;
	assign IB_w_enable[1] = ((IB_w_en == 1'b1) && (i_ch_2 == 1)) ? 1'b1 : 1'b0;
	assign IB_w_enable[2] = ((IB_w_en == 1'b1) && (i_ch_2 == 2)) ? 1'b1 : 1'b0;
	assign IB_w_enable[3] = ((IB_w_en == 1'b1) && (i_ch_2 == 3)) ? 1'b1 : 1'b0;
	assign IB_SRAM_r = i_r_2;
	assign IB_SRAM_c = i_c_2;

    assign T_input_size = ((stride << 3) - stride) + kernel_size;

    assign Input_SRAM_w_d = SRAM_store;

    assign DRAM_Address = my_DRAM_Address;
	assign Input_SRAM_w_addr = my_Input_SRAM_w_addr;
	assign Input_SRAM_r_addr = my_input_SRAM_start_address + my_input_SRAM_add_address;

    always@(*) begin
    	if(IC_Num[2:0] == 3'b0) begin
    		my_IC_Num = IC_Num;
    	end else begin
    		my_IC_Num = {IC_Num[($clog2(`MAX_INPUT_CHANNEL) - 1) : 3], 3'b0};
    	end
    	if(RC_Size[2:0] == 3'b0) begin
    		my_RC_Size = RC_Size;
    	end else begin
    		my_RC_Size = {RC_Size[($clog2(`MAX_FEATURE_SIZE) - 1) : 3], 3'b0};
    	end
    end

    always@(posedge clock) begin
    	if(reset == 1'b1) begin
    		SRAM_store = 0;
    	end else if (first_SRAM_store == 1'b1) begin
    		SRAM_store[31 : 0] = DRAM_ReadData;
    	end else if (second_SRAM_store == 1'b1) begin
    		SRAM_store[63 : 32] = DRAM_ReadData;
    	end else if (third_SRAM_store == 1'b1) begin
    		SRAM_store[95 : 64] = DRAM_ReadData;
    	end else if (fourth_SRAM_store == 1'b1) begin
    		SRAM_store[127 : 96] = DRAM_ReadData;
    	end
    end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			i_ch_1 = 0;
			i_r_1 = 0;
			i_c_1 = 0;
		end else if (i_SRAM_inc == 1'b1) begin
			i_c_1 = i_c_1 + 8;
			if(i_c_1 >= my_RC_Size) begin
				i_c_1 = 0;
				if(i_r_1 >= my_RC_Size) begin
					i_r_1 = 0;
					i_ch_1 = i_ch_1 + 1;
				end else begin
					i_r_1 = i_r_1 + 1;
				end
			end else begin
			end
		end
	end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			my_DRAM_Address = input_start_address;
		end else if (i_DRAM_inc == 1'b1) begin
			my_DRAM_Address = my_DRAM_Address + 4;
		end
	end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			my_Input_SRAM_w_addr = 0;
		end else if (i_SRAM_inc == 1'b1) begin
			my_Input_SRAM_w_addr = my_Input_SRAM_w_addr + 8;
		end
	end

	parameter WAIT_FOR_START = 5'd0,
			S_CHECK_IDX = 5'd1,
			S_DRAM_WAIT_FIRST = 5'd2,
			S_IDX_PLUS_FIRST = 5'd3,
			S_DRAM_WAIT_SECOND = 5'd4,
			S_IDX_PLUS_SECOND = 5'd5,
			S_DRAM_WAIT_THIRD = 5'd6,
			S_IDX_PLUS_THIRD = 5'd7,
			S_DRAM_WAIT_FOURTH = 5'd8,
			S_SRAM_ST = 5'd9,
			S_IDX_PLUS_FOURTH = 5'd10,
			S_FINISH = 5'd11,
			B_CHECK_IDX = 5'd12,
			B_SRAM_LD = 5'd13,
			B_BUFF_ST = 5'd14,
			B_IDX_PLUS = 5'd15,
			B_FIRST_IDX_PLUS = 5'd16,
			B_FINISH = 5'd17;

	reg [3:0] state, next_state;

    always@(*) begin
        next_state = WAIT_FOR_START;
        case (state)
            WAIT_FOR_START:
                if(start_SRAM_load) begin
                    next_state = S_CHECK_IDX;
                end else if(start_buffer_load) begin
                    next_state = B_CHECK_IDX;
                end else begin
                	next_state = WAIT_FOR_START;
                end

            S_CHECK_IDX:
            	if((i_ch_1 == my_IC_Num) && (i_r_1 == my_RC_Size) && (i_c_1 == my_RC_Size)) begin
            		next_state = S_FINISH;
            	end else begin
            		next_state = S_DRAM_WAIT_FIRST;
            	end

            S_DRAM_WAIT_FIRST:
            	if(DRAM_DataReady == 1'b1) begin
            		next_state = S_IDX_PLUS_FIRST;
            	end else begin
            		next_state = S_DRAM_WAIT_FIRST;
            	end

            S_IDX_PLUS_FIRST: next_state = S_DRAM_WAIT_SECOND;

            S_DRAM_WAIT_SECOND:
            	if(DRAM_DataReady == 1'b1) begin
            		next_state = S_IDX_PLUS_SECOND;
            	end else begin
            		next_state = S_DRAM_WAIT_SECOND;
            	end

            S_IDX_PLUS_SECOND: next_state = S_DRAM_WAIT_THIRD;

            S_DRAM_WAIT_THIRD:
            	if(DRAM_DataReady == 1'b1) begin
            		next_state = S_IDX_PLUS_THIRD;
            	end else begin
            		next_state = S_DRAM_WAIT_THIRD;
            	end

            S_IDX_PLUS_THIRD: next_state = S_DRAM_WAIT_FOURTH;

            S_DRAM_WAIT_FOURTH:
            	if(DRAM_DataReady == 1'b1) begin
            		next_state = S_SRAM_ST;
            	end else begin
            		next_state = S_DRAM_WAIT_FOURTH;
            	end

            S_SRAM_ST: begin
            	if(Input_SRAM_w_done == 1'b1) begin        		
	            	next_state = S_IDX_PLUS_FOURTH;
	            end else begin
	            	next_state = S_SRAM_ST;
	            end
            end

            S_IDX_PLUS_FOURTH: next_state = S_CHECK_IDX;

            S_FINISH: next_state = WAIT_FOR_START;

			B_CHECK_IDX: begin
				if((i_ch_2 == (`INPUT_CHANNEL-1)) && (i_r_2 == T_input_size) && (i_c_2 == T_input_size)) begin
            		next_state = B_FIRST_IDX_PLUS;
            	end else begin
            		next_state = B_SRAM_LD;
            	end
			end

			B_SRAM_LD: begin
				if(Input_SRAM_d_ready == 1'b1) begin
					next_state = B_BUFF_ST;
				end else begin
					next_state = B_SRAM_LD;
				end
			end

			B_BUFF_ST: next_state = B_IDX_PLUS;

			B_IDX_PLUS: next_state = B_CHECK_IDX;

			B_FIRST_IDX_PLUS: next_state = B_FINISH;

			B_FINISH: next_state = WAIT_FOR_START;

            default: next_state = WAIT_FOR_START;
        endcase
    end

	always@(*) begin
		finished = 1'b0;
		DRAM_Read = 1'b0;
		i_DRAM_inc = 1'b0;
		i_SRAM_inc = 1'b0;
		first_SRAM_store = 1'b0;
		second_SRAM_store = 1'b0;
		third_SRAM_store = 1'b0;
		fourth_SRAM_store = 1'b0;
		Input_SRAM_w_en = 1'b0;
		Input_SRAM_r_en = 1'b0;
		first_inc_enable = 1'b0;
		add_inc_enable = 1'b0;
		add_inc_reset = 1'b0;
		IB_w_en = 1'b0;

        case (state)

            S_DRAM_WAIT_FIRST: begin
				DRAM_Read = 1'b1;
				first_SRAM_store = 1'b1;
            end

            S_IDX_PLUS_FIRST: begin
            	i_DRAM_inc = 1'b1;
            end

            S_DRAM_WAIT_SECOND: begin
				DRAM_Read = 1'b1;
				second_SRAM_store = 1'b1;
            end

            S_IDX_PLUS_SECOND: begin
            	i_DRAM_inc = 1'b1;
            end

            S_DRAM_WAIT_THIRD: begin
				DRAM_Read = 1'b1;
				third_SRAM_store = 1'b1;
            end

            S_IDX_PLUS_THIRD: begin
            	i_DRAM_inc = 1'b1;
            end

            S_DRAM_WAIT_FOURTH: begin
				DRAM_Read = 1'b1;
				fourth_SRAM_store = 1'b1;
            end

            S_SRAM_ST: begin
            	Input_SRAM_w_en = 1'b1;
            end

            S_IDX_PLUS_FOURTH: begin
            	i_SRAM_inc = 1'b1;
            	i_DRAM_inc = 1'b1;
            end

            S_FINISH: begin
            	finished = 1'b1;
            end

			B_SRAM_LD: begin
				Input_SRAM_r_en = 1'b1;
			end

			B_BUFF_ST: begin
				IB_w_en = 1'b1;
			end

			B_IDX_PLUS: begin
				add_inc_enable = 1'b1;
			end

			B_FIRST_IDX_PLUS: begin
				first_inc_enable = 1'b1;
			end

			B_FINISH: begin
				add_inc_reset = 1'b1;
			end

            default: begin
				finished = 1'b0;
				DRAM_Read = 1'b0;
				i_SRAM_inc = 1'b0;
				i_SRAM_inc = 1'b0;
				first_SRAM_store = 1'b0;
				second_SRAM_store = 1'b0;
				third_SRAM_store = 1'b0;
				fourth_SRAM_store = 1'b0;
				first_inc_enable = 1'b0;
				add_inc_enable = 1'b0;
				add_inc_reset = 1'b0;
				IB_w_en = 1'b0;
            end
        endcase
    end


	always@(posedge clock) begin
        if(reset == 1'b1) begin
            state = WAIT_FOR_START;
        end else begin
            state = next_state;
        end
    end

endmodule