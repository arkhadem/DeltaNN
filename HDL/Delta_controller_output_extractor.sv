`include "sys_defs.svh"

module Delta_controller_output_extractor(
	input clock,
	input reset,

	input start_SRAM_extract,
	input start_buffer_extract,

    input [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] OC_Num,
    input [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] ORC_Size,

	input [31 : 0] output_start_address,

    // Output buffer ports
    output reg [(`OUTPUT_CHANNEL - 1) : 0] OB_r_enable [(`PU_NUM - 1) : 0],
    input [((`BIN_LEN * `OUTPUT_SRAM_LEN) - 1) : 0] OB_SRAM_out,
    output reg [($clog2(`OUTPUT_HEIGHT) - 1) : 0] OB_SRAM_r_out,
    output reg [($clog2(`OUTPUT_WIDTH) - 1) : 0] OB_SRAM_c_out,

    // Output SRAM ports
    output [63 : 0] Output_SRAM_w_d,
    input [63 : 0] Output_SRAM_r_d,
    output [31 : 0] Output_SRAM_w_addr,
    output [31 : 0] Output_SRAM_r_addr,
    output reg Output_SRAM_w_en,
    output reg Output_SRAM_r_en,
    input Output_SRAM_d_ready,
    input Output_SRAM_w_done,

    // DRAM access ports
	output reg DRAM_Write,
	output [31:0] DRAM_Address,
	output reg [31:0] DRAM_WriteData,
	input DRAM_WriteDone,

	output reg finished
);

	reg [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] my_OC_Num;
	reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] my_ORC_Size;

	reg [31 : 0] my_DRAM_Address;
	reg [31 : 0] my_Output_SRAM_r_addr;

    reg [63 : 0] SRAM_store;
    reg first_SRAM_store;
    reg second_SRAM_store;

	reg [(`MAX_OUTPUT_CHANNEL - 1) : 0] o_ch_1, o_ch_first;
	reg [(`MAX_FEATURE_SIZE - 1) : 0] o_r_1, o_r_first;
	reg [(`MAX_FEATURE_SIZE - 1) : 0] o_c_1, o_c_first;

	reg [($clog2(`PU_NUM - 1) + $clog2(`OUTPUT_CHANNEL) - 1) : 0] o_ch_2;
	reg [($clog2(`OUTPUT_HEIGHT) - 1) : 0] o_r_2;
	reg [($clog2(`OUTPUT_WIDTH) - 1) : 0] o_c_2;

	reg [31 : 0] my_Output_SRAM_start_address;
	reg [31 : 0] my_Output_SRAM_add_address;

	reg o_DRAM_inc, o_SRAM_inc;
	reg first_inc_enable;
	reg add_inc_enable;
	reg add_inc_reset;

	reg OB_r_en;

    always@(*) begin
    	if(OC_Num[2:0] == 3'b0) begin
    		my_OC_Num = OC_Num;
    	end else begin
    		my_OC_Num = {OC_Num[($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 3], 3'b0};
    	end
    	if(ORC_Size[2:0] == 3'b0) begin
    		my_ORC_Size = ORC_Size;
    	end else begin
    		my_ORC_Size = {ORC_Size[($clog2(`MAX_FEATURE_SIZE) - 1) : 3], 3'b0};
    	end
    end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			my_Output_SRAM_start_address = 0;
			o_ch_first = 0;
			o_r_first = 0;
			o_c_first = 0;
		end else if (first_inc_enable == 1'b1) begin
			if(o_c_first == my_ORC_Size) begin
				o_c_first = 0;
				if(o_r_first == my_ORC_Size) begin
					o_r_first = 0;
					o_ch_first = o_ch_first + `OUTPUT_CHANNEL;
					my_Output_SRAM_start_address = my_Output_SRAM_start_address + (my_ORC_Size << 2) - my_ORC_Size;// ((my_ORC_Size * my_ORC_Size) << 2) - (my_ORC_Size * my_ORC_Size);
				end else begin
					o_r_first = o_r_first + `OUTPUT_HEIGHT;
					my_Output_SRAM_start_address = my_Output_SRAM_start_address + (my_ORC_Size << 3); //((`OUTPUT_HEIGHT - 1) * my_ORC_Size);
				end
			end else begin
				o_c_first = o_c_first + `OUTPUT_WIDTH;
				my_Output_SRAM_start_address = my_Output_SRAM_start_address + `OUTPUT_WIDTH;
			end
		end
	end

	always@(posedge clock) begin
		if(add_inc_reset == 1'b1 || reset == 1'b1) begin
			my_Output_SRAM_add_address = 0;
			o_ch_2 = 0;
			o_r_2 = 0;
			o_c_2 = 0;			
		end else if(add_inc_enable == 1'b1) begin
			if(o_c_2 == `OUTPUT_WIDTH) begin
				o_c_2 = 0;
				if(o_r_2 == `OUTPUT_HEIGHT) begin
					o_r_2 = 0;
					o_ch_2 = o_ch_2 + 1;
					my_Output_SRAM_add_address = my_Output_SRAM_add_address + my_ORC_Size - `OUTPUT_HEIGHT; // (my_ORC_Size * my_ORC_Size) - (`OUTPUT_HEIGHT * `OUTPUT_WIDTH);
				end else begin
					o_r_2 = o_r_2 + 1;
					my_Output_SRAM_add_address = my_Output_SRAM_add_address + my_ORC_Size - `OUTPUT_WIDTH;
				end
			end else begin
				o_c_2 = o_c_2 + 8;
				my_Output_SRAM_add_address = my_Output_SRAM_add_address + 8;
			end
		end
	end

	always@(*) begin
		OB_SRAM_r_out = o_r_2;
		OB_SRAM_c_out = o_c_2;
		for (int i = 0; i < `PU_NUM; i++) begin
			for (int j = 0; j < `OUTPUT_CHANNEL; j++) begin
				if((i == o_ch_2[($clog2(`PU_NUM - 1) + $clog2(`OUTPUT_CHANNEL) - 1) : $clog2(`OUTPUT_CHANNEL)]) &&
				(j == o_ch_2[($clog2(`OUTPUT_CHANNEL) - 1) :0]) &&
				OB_r_en == 1'b1) begin
					OB_r_enable[i][j] = 1'b1;
				end else begin
					OB_r_enable[i][j] = 1'b0;
				end
			end
		end
	end

	assign Output_SRAM_w_d = OB_SRAM_out;

    assign DRAM_Address = my_DRAM_Address;
	assign Output_SRAM_r_addr = my_Output_SRAM_r_addr;
	assign Output_SRAM_w_addr = my_Output_SRAM_start_address + my_Output_SRAM_add_address;


    always@(posedge clock) begin
    	if(reset == 1'b1) begin
    		DRAM_WriteData = 0;
    	end else if (first_SRAM_store == 1'b1) begin
    		DRAM_WriteData = Output_SRAM_r_d[31 : 0];
    	end else if (second_SRAM_store == 1'b1) begin
    		DRAM_WriteData = Output_SRAM_r_d[63 : 32];
    	end
    end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			o_ch_1 = 0;
			o_r_1 = 0;
			o_c_1 = 0;
		end else if (o_SRAM_inc == 1'b1) begin
			o_c_1 = o_c_1 + 8;
			if(o_c_1 >= my_ORC_Size) begin
				o_c_1 = 0;
				if(o_r_1 >= my_ORC_Size) begin
					o_r_1 = 0;
					o_ch_1 = o_ch_1 + 1;
				end else begin
					o_r_1 = o_r_1 + 1;
				end
			end else begin
			end
		end
	end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			my_DRAM_Address = output_start_address;
		end else if (o_DRAM_inc == 1'b1) begin
			my_DRAM_Address = my_DRAM_Address + 4;
		end
	end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			my_Output_SRAM_r_addr = 0;
		end else if (o_SRAM_inc == 1'b1) begin
			my_Output_SRAM_r_addr = my_Output_SRAM_r_addr + 8;
		end
	end

	parameter WAIT_FOR_START = 4'd0,
			S_CHECK_IDX = 4'd1,
			S_SRAM_LD = 4'd2,
			S_DRAM_WAIT_FIRST = 4'd3,
			S_IDX_PLUS_FIRST = 4'd4,
			S_DRAM_WAIT_SECOND = 4'd5,
			S_IDX_PLUS_SECOND = 4'd6,
			S_FINISH = 4'd7,

			B_CHECK_IDX = 4'd8,
			B_BUFF_LD = 4'd9,
			B_SRAM_ST = 4'd10,
			B_IDX_PLUS = 4'd11,
			B_FIRST_IDX_PLUS = 4'd12,
			B_FINISH = 4'd13;

	reg [3:0] state, next_state;

    always@(*) begin
        next_state = WAIT_FOR_START;
        case (state)
            WAIT_FOR_START:
                if(start_SRAM_extract) begin
                    next_state = S_CHECK_IDX;
                end else if(start_buffer_extract) begin
                    next_state = B_CHECK_IDX;
                end else begin
                	next_state = WAIT_FOR_START;
                end

            S_CHECK_IDX:
            	if((o_ch_1 == my_OC_Num) && (o_r_1 == my_ORC_Size) && (o_c_1 == my_ORC_Size)) begin
            		next_state = S_FINISH;
            	end else begin
            		next_state = S_SRAM_LD;
            	end

			S_SRAM_LD:
				if(Output_SRAM_d_ready == 1'b1) begin
					next_state = S_DRAM_WAIT_FIRST;
				end else begin
					next_state = S_SRAM_LD;
				end

            S_DRAM_WAIT_FIRST:
            	if(DRAM_WriteDone == 1'b1) begin
            		next_state = S_IDX_PLUS_FIRST;
            	end else begin
            		next_state = S_DRAM_WAIT_FIRST;
            	end

            S_IDX_PLUS_FIRST: next_state = S_DRAM_WAIT_SECOND;

            S_DRAM_WAIT_SECOND:
            	if(DRAM_WriteDone == 1'b1) begin
            		next_state = S_IDX_PLUS_SECOND;
            	end else begin
            		next_state = S_DRAM_WAIT_SECOND;
            	end

            S_IDX_PLUS_SECOND: next_state = S_CHECK_IDX;

            S_FINISH: next_state = WAIT_FOR_START;

			B_CHECK_IDX: begin
				if((o_ch_2 == 16) && (o_r_2 == `OUTPUT_HEIGHT) && (o_c_2 == `OUTPUT_WIDTH)) begin
            		next_state = B_FIRST_IDX_PLUS;
            	end else begin
            		next_state = B_BUFF_LD;
            	end
			end

			B_BUFF_LD: next_state = B_SRAM_ST;

			B_SRAM_ST: begin
				if(Output_SRAM_w_done == 1'b1) begin
					next_state = B_IDX_PLUS;
				end else begin
					next_state = B_SRAM_ST;
				end
			end

			B_IDX_PLUS: next_state = B_CHECK_IDX;

			B_FIRST_IDX_PLUS: next_state = B_FINISH;

			B_FINISH: next_state = WAIT_FOR_START;

            default: next_state = WAIT_FOR_START;
        endcase
    end

	always@(*) begin
		DRAM_Write = 1'b0;
		o_DRAM_inc = 1'b0;
		o_SRAM_inc = 1'b0;
		first_SRAM_store = 1'b0;
		second_SRAM_store = 1'b0;
		Output_SRAM_w_en = 1'b0;
		Output_SRAM_r_en = 1'b0;
		first_inc_enable = 1'b0;
		add_inc_enable = 1'b0;
		add_inc_reset = 1'b0;
		OB_r_en = 1'b0;
		finished = 1'b0;
        case (state)

            S_SRAM_LD: begin
            	Output_SRAM_r_en = 1'b1;
            end

            S_DRAM_WAIT_FIRST: begin
				DRAM_Write = 1'b1;
				first_SRAM_store = 1'b1;
            end

            S_IDX_PLUS_FIRST: begin
            	o_DRAM_inc = 1'b1;
            end

            S_DRAM_WAIT_SECOND: begin
				DRAM_Write = 1'b1;
				second_SRAM_store = 1'b1;
            end

            S_IDX_PLUS_SECOND: begin
            	o_SRAM_inc = 1'b1;
            	o_DRAM_inc = 1'b1;
            end

            S_FINISH: begin
            	finished = 1'b1;
            end


			B_BUFF_LD: begin
				OB_r_en = 1'b1;
			end

			B_SRAM_ST: begin
				Output_SRAM_w_en = 1'b1;
			end

			B_IDX_PLUS: begin
				add_inc_enable = 1'b1;
			end

			B_FIRST_IDX_PLUS: begin
				first_inc_enable = 1'b1;
			end

			B_FINISH: begin
				add_inc_reset = 1'b1;
				finished = 1'b1;
			end

            default: begin
				DRAM_Write = 1'b0;
				o_SRAM_inc = 1'b0;
				o_SRAM_inc = 1'b0;
				first_SRAM_store = 1'b0;
				second_SRAM_store = 1'b0;
				first_inc_enable = 1'b0;
				add_inc_enable = 1'b0;
				add_inc_reset = 1'b0;
				OB_r_en = 1'b0;
				finished = 1'b0;
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