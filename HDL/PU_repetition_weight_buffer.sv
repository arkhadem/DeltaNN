`include "sys_defs.svh"

module PU_repetition_weight_buffer (
    input clock,
    input reset,
    input start,
    input enable,	// enable shows if there's not stall
    input finish,

    output reg [31 : 0] word_counter,
    output reg word_read,
    input word_ready,

    input [(`WEIGHT_SRAM_LEN - 1) : 0] SRAM_in,

    input [($clog2(`MAX_WEIGHT_NUM_LEN) - 1) : 0] weight_num_len,

    output new_weight,
    output reg busy,
    output reg filled
);

	reg [((2 * `WEIGHT_SRAM_LEN) - 1) : 0] my_register;
	
	reg [$clog2(`WEIGHT_SRAM_LEN) : 0] my_register_valid_num;

	reg valid_num_inc_en, valid_num_dec_en;

	reg word_counter_en;

	wire read_word;

    reg operate;

    reg [(`MAX_WEIGHT_NUM_LEN - 1) : 0] current_weight;

	assign read_word = (my_register_valid_num < `WEIGHT_SRAM_LEN) ? 1 : 0;
	assign new_weight = (current_weight == 0) ? 1 : 0;

    always@(*) begin
        current_weight = 0;
        for (int i = 0; i < weight_num_len; i++) begin
            current_weight[i] = my_register[i];
        end
    end

	always@(posedge clock) begin
		if(reset) begin
			my_register = 0;
		end else if(enable) begin
            if(word_ready)
                my_register[my_register_valid_num +: `WEIGHT_SRAM_LEN] = SRAM_in;
            else if(operate)
                if(current_weight == 0)
                    my_register = (my_register >> weight_num_len) - 1;
                else
                    my_register = my_register - 1;
        end
    end

	always@(posedge clock) begin
		if(reset)
			my_register_valid_num = 0;
		else if(enable) begin
			if(valid_num_inc_en)
				my_register_valid_num = my_register_valid_num + `WEIGHT_SRAM_LEN;
			else if(valid_num_dec_en)
				if(current_weight == 0)
					my_register_valid_num = my_register_valid_num - weight_num_len;
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
        operate = 0;
        busy = 0;
        filled = 0;

        case (state)

            LOAD_WORD_1: begin
            	word_read = 1;
                busy = 1;
            end

            STORE_WORD_1: begin
            	word_counter_en = 1;
            	valid_num_inc_en = 1;
                busy = 1;
            end

            LOAD_WORD_2: begin
            	word_read = 1;
                busy = 1;
            end

            STORE_WORD_2: begin
            	word_counter_en = 1;
            	valid_num_inc_en = 1;
                busy = 1;
            end

           	OPERATION: begin
           		valid_num_dec_en = 1;
                operate = 1;
                filled = 1;
            end

            LOAD_WORD: begin
            	word_read = 1;
                busy = 1;
                filled = 1;
                end

            STORE_WORD: begin
            	word_counter_en = 1;
            	valid_num_inc_en = 1;
                busy = 1;
                filled = 1;
            end

            default: begin
            	word_read = 0;
    	    	word_counter_en = 0;
    			valid_num_inc_en = 0;
    			valid_num_dec_en = 0;
                operate = 0;
                busy = 0;
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