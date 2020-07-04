`include "sys_defs.svh"

module Delta_controller(
	input clock,
	input reset,

	//DeltaAcc Signals
	input start,
	output reg ack,
	output reg done,
    input [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] IC_Num,
    input [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] OC_Num,

    input [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] RC_Size,
    input [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] ORC_Size,
    input [3 : 0] kernel_size,
    input [2 : 0] stride,

    input [($clog2(`MAX_WEIGHT_DELTA_LEN) - 1) : 0] weight_delta_len,
    input [($clog2(`MAX_WEIGHT_NUM_LEN) - 1) : 0] weight_num_len,
    input [($clog2(`MAX_IDX_DELTA_LEN) - 1) : 0] idx_delta_len,

    input load_input,
	input store_output,

	input [31 : 0] weight_start_address,
	input [31 : 0] weight_idx_start_offset,
	input [31 : 0] weight_unique_start_offset,
	input [31 : 0] weight_repetition_start_offset,
	input [31 : 0] bias_start_address,
	input [31 : 0] input_start_address,
	input [31 : 0] output_start_address,

	// DRAM ports
	output reg DRAM_Read,
	output DRAM_Write,
	output reg [31:0] DRAM_Address,
	input [31:0] DRAM_ReadData,
	output [31:0] DRAM_WriteData,
	input DRAM_DataReady,
	input DRAM_WriteDone,

	// PU ports
    // Output Buffer ports
    output [(`OUT_BIN_LEN - 1) : 0] OB_bias [(`PU_NUM - 1) : 0][(`OUTPUT_CHANNEL - 1) : 0],
    output [(`OUTPUT_CHANNEL - 1) : 0] OB_w_enable [(`PU_NUM - 1) : 0],
    output [(`OUTPUT_CHANNEL - 1) : 0] OB_r_enable [(`PU_NUM - 1) : 0],
    input [((`BIN_LEN * `OUTPUT_SRAM_LEN) - 1) : 0] OB_SRAM_out,
    output [($clog2(`OUTPUT_HEIGHT) - 1) : 0] OB_SRAM_r_out,
    output [($clog2(`OUTPUT_WIDTH) - 1) : 0] OB_SRAM_c_out,

    // Input Buffer ports
    output [(`INPUT_CHANNEL - 1) : 0] IB_w_enable,
	output [(`INPUT_CHANNEL - 1) : 0] IB_r_enable,
    output [($clog2(`INPUT_HEIGHT) - 1) : 0] IB_SRAM_r,
    output [($clog2(`INPUT_WIDTH) - 1) : 0] IB_SRAM_c,

    // Weight Buffer ports
    output [(`PU_NUM - 1) : 0] WB_SRAM_ready,
    input [(`PU_NUM - 1) : 0] WB_SRAM_read,
    input [31 : 0] WB_SRAM_address [(`PU_NUM - 1) : 0],

    // Weight SRAM ports
    output [31 : 0] Weight_SRAM_addr,
    output Weight_SRAM_w_en,
    output Weight_SRAM_r_en,
    input Weight_SRAM_d_ready,
    input Weight_SRAM_w_done,

    // Input SRAM ports
    output [63 : 0] Input_SRAM_w_d,
    output [31 : 0] Input_SRAM_w_addr,
    output [31 : 0] Input_SRAM_r_addr,
    output Input_SRAM_w_en,
    output Input_SRAM_r_en,
    input Input_SRAM_d_ready,
    input Input_SRAM_w_done,

    // Output SRAM ports
    output [63 : 0] Output_SRAM_w_d,
    input [63 : 0] Output_SRAM_r_d,
    output [31 : 0] Output_SRAM_w_addr,
    output [31 : 0] Output_SRAM_r_addr,
    output Output_SRAM_w_en,
    output Output_SRAM_r_en,
    input Output_SRAM_d_ready,
    input Output_SRAM_w_done,

    // PU ports
    output reg PU_start,
	output reg [($clog2(`INPUT_CHANNEL) - 1) : 0] PU_IC_Num,
	output reg [($clog2(`OUTPUT_CHANNEL) - 1) : 0] PU_OC_Num [(`PU_NUM - 1) : 0],
	input [(`PU_NUM - 1) : 0] PU_finished
);

	wire DRAM_Read_bias, DRAM_Read_input, DRAM_Read_weight;
	wire [31 : 0] DRAM_Address_bias, DRAM_Address_input, DRAM_Address_output, DRAM_Address_weight;
	wire bias_finished, input_finished, output_finished;
	reg start_bias_load, start_input_SRAM_load, start_input_buffer_load, start_output_SRAM_extract, start_output_buffer_extract, start_weight_manage, finish_cycle;
	wire total_finished;

    reg [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] my_OC_Num;
    reg [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] my_IC_Num;
    reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] my_RC_Size;
    reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] my_ORC_Size;

	reg [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] i_ch;
	reg [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] o_ch;
	reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] o_r;
	reg [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] o_c;
	reg idx_inc_en;

	reg[1:0] DRAM_type;

	Delta_controller_bias_loader Delta_controller_bias_loader_inst(
		.clock(clock),
		.reset(reset),
		.start(start_bias_load),

		.OC_Num(OC_Num),
	    .ORC_Size(ORC_Size),

	    .bias_start_address(bias_start_address),

	    // PU signals for writing bias data
	    .OB_bias(OB_bias),
	    .OB_w_enable(OB_w_enable),

	    // DRAM access ports
		.DRAM_Read(DRAM_Read_bias),
		.DRAM_Address(DRAM_Address_bias),
		.DRAM_ReadData(DRAM_ReadData),
		.DRAM_DataReady(DRAM_DataReady),

	    .finished(bias_finished)
	);

	Delta_controller_input_loader Delta_controller_input_loader_inst(
		.clock(clock),
		.reset(reset),

		.start_SRAM_load(start_input_SRAM_load),
		.start_buffer_load(start_input_buffer_load),

	    .IC_Num(IC_Num),
	    .RC_Size(RC_Size),

	    .stride(stride),
	    .kernel_size(kernel_size),

	    .input_start_address(input_start_address),

	    // DRAM access ports
		.DRAM_Read(DRAM_Read_input),
		.DRAM_Address(DRAM_Address_input),
		.DRAM_ReadData(DRAM_ReadData),
		.DRAM_DataReady(DRAM_DataReady),

		// Input SRAM access ports
	    .Input_SRAM_w_d(Input_SRAM_w_d),
	    .Input_SRAM_w_addr(Input_SRAM_w_addr),
	    .Input_SRAM_r_addr(Input_SRAM_r_addr),
	    .Input_SRAM_w_en(Input_SRAM_w_en),
	    .Input_SRAM_r_en(Input_SRAM_r_en),
	    .Input_SRAM_d_ready(Input_SRAM_d_ready),
	    .Input_SRAM_w_done(Input_SRAM_w_done),

		// Input buffer access ports
	    .IB_w_enable(IB_w_enable),
	    .IB_SRAM_r(IB_SRAM_r),
	    .IB_SRAM_c(IB_SRAM_c),

	    .finished(input_finished)
	);

	Delta_controller_output_extractor Delta_controller_output_extractor_inst(
		.clock(clock),
		.reset(reset),

		.start_SRAM_extract(start_output_SRAM_extract),
		.start_buffer_extract(start_output_buffer_extract),

	    .OC_Num(OC_Num),
	    .ORC_Size(ORC_Size),

		.output_start_address(output_start_address),

	    // Output buffer ports
	    .OB_r_enable(OB_r_enable),
	    .OB_SRAM_out(OB_SRAM_out),
	    .OB_SRAM_r_out(OB_SRAM_r_out),
	    .OB_SRAM_c_out(OB_SRAM_c_out),

	    // Output SRAM ports
	    .Output_SRAM_w_d(Output_SRAM_w_d),
	    .Output_SRAM_r_d(Output_SRAM_r_d),
	    .Output_SRAM_w_addr(Output_SRAM_w_addr),
	    .Output_SRAM_r_addr(Output_SRAM_r_addr),
	    .Output_SRAM_w_en(Output_SRAM_w_en),
	    .Output_SRAM_r_en(Output_SRAM_r_en),
	    .Output_SRAM_d_ready(Output_SRAM_d_ready),
	    .Output_SRAM_w_done(Output_SRAM_w_done),

	    // DRAM access ports
		.DRAM_Write(DRAM_Write),
		.DRAM_Address(DRAM_Address_output),
		.DRAM_WriteData(DRAM_WriteData),
		.DRAM_WriteDone(DRAM_WriteDone),

		.finished(output_finished)
	);

	Delta_controller_weight_manager Delta_controller_weight_manager_inst(
		.clock(clock),
		.reset(reset),

		.start(start_weight_manage),
		.finish_cycle(finish_cycle),

	    .OC_Num(OC_Num),
	    .IC_Num(IC_Num),
	    .ORC_Size(ORC_Size),

		.weight_start_address(weight_start_address),

	    // Weight buffer ports
	    .WB_SRAM_ready(WB_SRAM_ready),
	    .WB_SRAM_read(WB_SRAM_read),
	    .WB_SRAM_address(WB_SRAM_address),

	    // Weight SRAM ports
	    .Weight_SRAM_addr(Weight_SRAM_addr),
	    .Weight_SRAM_w_en(Weight_SRAM_w_en),
	    .Weight_SRAM_r_en(Weight_SRAM_r_en),
	    .Weight_SRAM_d_ready(Weight_SRAM_d_ready),
	    .Weight_SRAM_w_done(Weight_SRAM_w_done),

		// DRAM access ports
		.DRAM_Read(DRAM_Read_weight),
		.DRAM_Address(DRAM_Address_weight),
		.DRAM_DataReady(DRAM_DataReady)
	);

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
    	if(RC_Size[2:0] == 3'b0) begin
    		my_RC_Size = RC_Size;
    	end else begin
    		my_RC_Size = {RC_Size[($clog2(`MAX_FEATURE_SIZE) - 1) : 3], 3'b0};
    	end
    	if(ORC_Size[2:0] == 3'b0) begin
    		my_ORC_Size = ORC_Size;
    	end else begin
    		my_ORC_Size = {ORC_Size[($clog2(`MAX_FEATURE_SIZE) - 1) : 3], 3'b0};
    	end
    end

	always@(posedge clock) begin
		if(reset == 1'b1) begin
			i_ch = 0;
			o_ch = 0;
			o_r = 0;
			o_c = 0;
		end else if(idx_inc_en == 1'b1) begin		// increamented when delta cycle is finished
			i_ch = i_ch + `INPUT_CHANNEL;
			if(i_ch == my_IC_Num) begin
				i_ch = 0;
				o_c = o_c + `OUTPUT_WIDTH;
				if(o_c == my_ORC_Size) begin
					o_c = 0;
					o_r = o_r + `OUTPUT_HEIGHT;
					if(o_r == my_ORC_Size) begin
						o_r = 0;
						o_ch = o_ch + (`OUTPUT_CHANNEL * `PU_NUM);
					end
				end
			end
		end
	end

	// BEGIN HARDCODED
	always@(*) begin
		if((i_ch + `INPUT_CHANNEL) <= IC_Num) begin
			PU_IC_Num = `INPUT_CHANNEL;
		end else begin
			PU_IC_Num = IC_Num - i_ch;
		end

		if((o_ch + 8) <= OC_Num) begin
			PU_OC_Num[0] = 8;
		end else begin
			PU_OC_Num[0] = OC_Num - o_ch;
		end

		if((o_ch + 16) <= OC_Num) begin
			PU_OC_Num[1] = 8;
		end else begin
			PU_OC_Num[1] = OC_Num - o_ch - 8;
		end

		if((o_ch + 24) <= OC_Num) begin
			PU_OC_Num[2] = 8;
		end else begin
			PU_OC_Num[2] = OC_Num - o_ch - 16;
		end

		if((o_ch + 32) <= OC_Num) begin
			PU_OC_Num[3] = 8;
		end else begin
			PU_OC_Num[3] = OC_Num - o_ch - 24;
		end
	end

	assign total_finished = PU_finished[0] & PU_finished[1] & PU_finished[2] & PU_finished[3];

	// END HARDCODED

	parameter   DRAM_INPUT = 2'd0,
				DRAM_OUTPUT = 2'd1,
				DRAM_BIAS = 2'd2,
				DRAM_WEIGHT = 2'd3;

	always@(*) begin
		case (DRAM_type)
			DRAM_INPUT: begin
				DRAM_Address = DRAM_Address_input;
				DRAM_Read = DRAM_Read_input;
			end
			DRAM_OUTPUT: begin
				DRAM_Address = DRAM_Address_output;
				DRAM_Read = 0;
			end
			DRAM_BIAS: begin
				DRAM_Address = DRAM_Address_bias;
				DRAM_Read = DRAM_Read_bias;
			end
			DRAM_WEIGHT: begin
				DRAM_Address = DRAM_Address_weight;
				DRAM_Read = DRAM_Read_weight;
			end
			default : begin
				DRAM_Address = 0;
				DRAM_Read = 0;
			end
		endcase
	end	

	parameter   WAIT_FOR_START = 5'd0,
				START_ACK = 5'd1,
				INPUT_SRAM_LD_START = 5'd2,
				INPUT_SRAM_LD_WAIT = 5'd3,

				CHECK_IDX = 5'd4,			
				
				BIAS_LD_START = 5'd5,
				BIAS_LD_WAIT = 5'd6,

				INPUT_BUFFER_LD_START = 5'd7,
				INPUT_BUFFER_LD_WAIT = 5'd8,

            	OPERATION_START = 5'd9,
            	OPERATION_WAIT = 5'd10,
            	OPERATION_FINISH = 5'd11,

            	OUTPUT_BUFFER_ST_START = 5'd12,
            	OUTPUT_BUFFER_ST_WAIT = 5'd13,
            	
            	IDX_PLUS = 5'd14,

            	OUTPUT_SRAM_ST_START = 5'd15,
            	OUTPUT_SRAM_ST_WAIT = 5'd16,
	        	DONE_SIGNAL = 5'd17;

    reg [4:0] state, next_state;


    always@(*) begin
        next_state = WAIT_FOR_START;
        case (state)
            WAIT_FOR_START:
                if(start)
                    next_state = START_ACK;
                else
                    next_state = WAIT_FOR_START;

            START_ACK:
            	if(load_input == 1'b1) begin
            		next_state = INPUT_SRAM_LD_START;
            	end else begin
            		next_state = CHECK_IDX;
            	end

            INPUT_SRAM_LD_START: next_state = INPUT_SRAM_LD_WAIT;

            INPUT_SRAM_LD_WAIT:
            	if(input_finished == 1'b1) begin
            		next_state = CHECK_IDX;
            	end else begin
            		next_state = INPUT_SRAM_LD_WAIT;
            	end

            CHECK_IDX:
            	if(i_ch == my_IC_Num && o_ch == my_OC_Num && o_r == my_ORC_Size && o_c == my_ORC_Size) begin
            		if(store_output == 1'b1) begin
            			next_state = OUTPUT_SRAM_ST_START;
            		end else begin
            			next_state = DONE_SIGNAL;
            		end
            	end else begin
            		if(i_ch == 0) begin
            			next_state = BIAS_LD_START;
            		end else begin
            			next_state = INPUT_BUFFER_LD_START;
            		end
            	end

            BIAS_LD_START: next_state = BIAS_LD_WAIT;
			
			BIAS_LD_WAIT:
				if(bias_finished) begin
					next_state = INPUT_BUFFER_LD_START;
				end else begin
					next_state = BIAS_LD_WAIT;
				end

            INPUT_BUFFER_LD_START: next_state = INPUT_BUFFER_LD_WAIT;

			INPUT_BUFFER_LD_WAIT:
				if(input_finished == 1'b1) begin
					next_state = OPERATION_START;
				end else begin
					next_state = INPUT_BUFFER_LD_WAIT;
				end

			OPERATION_START: next_state = OPERATION_WAIT;

			OPERATION_WAIT:
				if(total_finished == 1'b1) begin
					next_state = OPERATION_FINISH;					
				end else begin
					next_state = OPERATION_WAIT;
				end

			OPERATION_FINISH: begin
				if(o_ch == my_OC_Num) begin
					next_state = OUTPUT_BUFFER_ST_START;
				end else begin
					next_state = IDX_PLUS;
				end
			end

			OUTPUT_BUFFER_ST_START: next_state = OUTPUT_BUFFER_ST_WAIT;
			
			OUTPUT_BUFFER_ST_WAIT:
				if(output_finished == 1'b1) begin
					next_state = IDX_PLUS;
				end else begin
					next_state = OUTPUT_BUFFER_ST_WAIT;
				end
			
			IDX_PLUS: next_state = CHECK_IDX;

			OUTPUT_SRAM_ST_START: next_state = OUTPUT_SRAM_ST_WAIT;
			
			OUTPUT_SRAM_ST_WAIT:
				if(output_finished == 1'b1) begin
					next_state = DONE_SIGNAL;
				end else begin
					next_state = OUTPUT_SRAM_ST_WAIT;
				end
			
			DONE_SIGNAL: next_state = WAIT_FOR_START;

            default: next_state = WAIT_FOR_START;
        endcase
    end

    always@(*) begin
    	ack = 0;
		done = 0;
		PU_start = 0;
		start_bias_load = 0;
		start_input_SRAM_load = 0;
		start_input_buffer_load = 0;
		start_output_SRAM_extract = 0;
		start_output_buffer_extract = 0;
		start_weight_manage = 0;
		finish_cycle = 0;
		DRAM_type = 0;
		idx_inc_en = 0;
        case (state)
			
			START_ACK: begin
				ack = 1;
			end

			INPUT_SRAM_LD_START: begin
				start_input_SRAM_load = 1;
				DRAM_type = DRAM_INPUT;
			end

			INPUT_SRAM_LD_WAIT: begin
				DRAM_type = DRAM_INPUT;
			end

			BIAS_LD_START: begin
				start_bias_load = 1;
				DRAM_type = DRAM_BIAS;
			end

			BIAS_LD_WAIT: begin
				DRAM_type = DRAM_BIAS;
			end

			INPUT_BUFFER_LD_START: begin
				start_input_buffer_load = 1;
				DRAM_type = DRAM_INPUT;
			end

			INPUT_BUFFER_LD_WAIT: begin
				DRAM_type = DRAM_INPUT;
			end

			OPERATION_START: begin
				PU_start = 1;
				start_weight_manage = 1;
				DRAM_type = DRAM_WEIGHT;
			end

			OPERATION_WAIT: begin
				DRAM_type = DRAM_WEIGHT;
			end

			OPERATION_FINISH: begin
				finish_cycle = 1;
				DRAM_type = DRAM_WEIGHT;
			end

			OUTPUT_BUFFER_ST_START: begin
				start_output_buffer_extract = 1;
				DRAM_type = DRAM_OUTPUT;
			end

			OUTPUT_BUFFER_ST_WAIT: begin
				DRAM_type = DRAM_OUTPUT;
			end

			IDX_PLUS: begin
				idx_inc_en = 1;
			end

			OUTPUT_SRAM_ST_START: begin
				start_output_SRAM_extract = 1;
				DRAM_type = DRAM_OUTPUT;
			end

			OUTPUT_SRAM_ST_WAIT: begin
				DRAM_type = DRAM_OUTPUT;
			end

			DONE_SIGNAL: begin
				done = 1;
			end


            default: begin
    	    	ack = 0;
				done = 0;
				PU_start = 0;
				start_bias_load = 0;
				start_input_SRAM_load = 0;
				start_input_buffer_load = 0;
				start_output_SRAM_extract = 0;
				start_output_buffer_extract = 0;
				start_weight_manage = 0;
				finish_cycle = 0;
				DRAM_type = 0;
				idx_inc_en = 0;
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