`include "sys_defs.svh"

module PU_idx_buffer (
    input clock,
    input reset,
    input start,
    input enable,	// enable shows if a new weight is needed
    input finish,

    output reg [31 : 0] word_counter,
    output reg word_read,
    input word_ready,

    input [(`WEIGHT_SRAM_LEN - 1) : 0] SRAM_in,

    input [($clog2(`MAX_IDX_DELTA_LEN) - 1) : 0] idx_delta_len,

    output [($clog2(`OUTPUT_CHANNEL) - 1) : 0] oc_val,
    output [($clog2(`KERNEL_HEIGHT) - 1) : 0] kr_val,
    output [($clog2(`KERNEL_WIDTH) - 1) : 0] kc_val,
    output index,
    output finished,
    output reg filled
);

	reg [((2 * `WEIGHT_SRAM_LEN) - 1) : 0] my_register;
	
	reg [$clog2(`WEIGHT_SRAM_LEN) : 0] my_register_valid_num;

	reg valid_num_inc_en, valid_num_dec_en;

	reg word_counter_en;

	wire read_word;

	reg word_shift;

    reg [($clog2(`OUTPUT_CHANNEL) + $clog2(`KERNEL_HEIGHT) + $clog2(`KERNEL_WIDTH) + 1) : 0] current_index;
    reg [($clog2(`OUTPUT_CHANNEL) + $clog2(`KERNEL_HEIGHT) + $clog2(`KERNEL_WIDTH) + 1) : 0] current_index_plus_one;

    always@(*) begin
        current_index = 0;
        for (int i = 0; i < idx_delta_len + 2; i++) begin
            current_index[i] = my_register[i];
        end
    end

    assign current_index_plus_one = current_index + 1;

	assign read_word = (my_register_valid_num < `WEIGHT_SRAM_LEN) ? 1 : 0;
	assign index = my_register[0];
	assign finished = ((current_index[0] == 1) && (current_index[(`MAX_IDX_DELTA_LEN + 1) : 1] == 0)) ? 1'b1 : 1'b0;

	reg [($clog2(`OUTPUT_CHANNEL) - 1) : 0] oc, oc_delta;
    reg [($clog2(`KERNEL_HEIGHT) - 1) : 0] kr, kr_delta;
    reg [($clog2(`KERNEL_WIDTH) - 1) : 0] kc, kc_delta;

    assign oc_val = oc;
    assign kr_val = kr;
    assign kc_val = kc;

    always@(*) begin
        kc_delta = current_index_plus_one[($clog2(`KERNEL_WIDTH) + 1) : 2];
        kr_delta = current_index_plus_one[($clog2(`KERNEL_WIDTH) + $clog2(`KERNEL_HEIGHT) + 1) : ($clog2(`KERNEL_WIDTH) + 2)];
        oc_delta = current_index_plus_one[($clog2(`KERNEL_WIDTH) + $clog2(`KERNEL_HEIGHT) + $clog2(`OUTPUT_CHANNEL) + 1) : ($clog2(`KERNEL_WIDTH) + $clog2(`KERNEL_HEIGHT) + 2)];
    end

	always@(posedge clock) begin
		if(reset) begin
			my_register = 0;
			oc = 0;
			kr = 0;
			kc = 0;
		end else if(enable) begin
			if(word_ready) begin
				my_register[my_register_valid_num +: `WEIGHT_SRAM_LEN] = SRAM_in;
			end else if(word_shift) begin
				if(my_register[0] == 1) begin
					if(my_register[1] == 1) begin // absolute index
						oc = my_register[($clog2(`OUTPUT_CHANNEL) + 1) : 2];
						kr = my_register[($clog2(`OUTPUT_CHANNEL) + $clog2(`KERNEL_HEIGHT) + 1) : ($clog2(`OUTPUT_CHANNEL) + 2)];
						kc = my_register[($clog2(`OUTPUT_CHANNEL) + $clog2(`KERNEL_HEIGHT) + $clog2(`KERNEL_WIDTH) + 1) : ($clog2(`OUTPUT_CHANNEL) + $clog2(`KERNEL_HEIGHT) + 1)];
						my_register = my_register >> ($clog2(`OUTPUT_CHANNEL) + $clog2(`KERNEL_HEIGHT) + $clog2(`KERNEL_WIDTH) + 2);
					end else begin		// delta index
						oc = oc + oc_delta;
						kr = kr + kr_delta;
						kc = kc + kc_delta;
						my_register = my_register >> (idx_delta_len + 2);
					end
				end else begin
					my_register = my_register >> 1;
				end
			end
		end
	end

	always@(posedge clock) begin
		if(reset)
			my_register_valid_num = 0;
		else if(enable) begin
			if(valid_num_inc_en)
				my_register_valid_num = my_register_valid_num + `WEIGHT_SRAM_LEN;
			else if(valid_num_dec_en)
				if(my_register[0] == 1)
					if(my_register[1] == 1) // absolute index
						my_register_valid_num = my_register_valid_num - ($clog2(`OUTPUT_CHANNEL) + $clog2(`KERNEL_HEIGHT) + $clog2(`KERNEL_WIDTH) + 2);
					else	// delta index
						my_register_valid_num = my_register_valid_num - (idx_delta_len + 2);
				else
					my_register_valid_num = my_register_valid_num - 1;
		end
	end

	parameter   IDLE = 3'd0,
				LOAD_WORD_1 = 3'd1,
				STORE_WORD_1 = 3'd2,
				LOAD_WORD_2 = 3'd3,
				STORE_WORD_2 = 3'd4,
				OPERATION = 3'd5,
				LOAD_WORD = 3'd6,
				STORE_WORD = 3'd7;

    reg [2:0] state, next_state;

    always@(*) begin
        next_state = IDLE;
        case (state)
            IDLE:
                if(start)
                    next_state = LOAD_WORD_1;
                else
                    next_state = IDLE;
              
            LOAD_WORD_1:
            	if(word_ready)
            		next_state = STORE_WORD_1;
            	else
            		next_state = LOAD_WORD_1;

            STORE_WORD_1: next_state = LOAD_WORD_2;

            LOAD_WORD_2:
            	if(word_ready)
            		next_state = STORE_WORD_2;
            	else
            		next_state = LOAD_WORD_2;

            STORE_WORD_2: next_state = OPERATION;

           	OPERATION:
           		if(finish)
           			next_state = IDLE;
           		else
           			if(read_word)
	           			next_state = LOAD_WORD;
	           		else
	           			next_state = OPERATION;

	        LOAD_WORD:
	        	if(word_ready)
            		next_state = STORE_WORD;
            	else
            		next_state = LOAD_WORD;

            STORE_WORD: next_state = OPERATION;

            default: next_state = IDLE;
        endcase
    end

    always@(state) begin
    	word_read = 0;
    	word_counter_en = 0;
		valid_num_inc_en = 0;
		valid_num_dec_en = 0;
		word_shift = 0;
        filled = 0;

        case (state)
            LOAD_WORD_1: begin
            	word_read = 1;
            end

            STORE_WORD_1: begin
            	word_counter_en = 1;
            	valid_num_inc_en = 1;
            end

            LOAD_WORD_2: begin
            	word_read = 1;
            end

            STORE_WORD_2: begin
            	word_counter_en = 1;
            	valid_num_inc_en = 1;
            end

           	OPERATION: begin
           		valid_num_dec_en = 1;
           		word_shift = 1;
                filled = 1;
            end

            LOAD_WORD: begin
            	word_read = 1;
                filled = 1;
            end
        
            STORE_WORD: begin
            	word_counter_en = 1;
            	valid_num_inc_en = 1;
                filled = 1;
            end

            default: begin
            	word_read = 0;
    	    	word_counter_en = 0;
    			valid_num_inc_en = 0;
    			valid_num_dec_en = 0;
    			word_shift = 0;
                filled = 0;
            end
        endcase

    end

	always@(posedge clock) begin
        if(reset) begin
            state = IDLE;
        end else if(enable) begin
            state = next_state;
        end
    end

    always@(posedge clock) begin
    	if(reset) begin
    		word_counter = 0;
    	end else if(word_counter_en & enable) begin
    		word_counter = word_counter + 1;
    	end
    end

endmodule