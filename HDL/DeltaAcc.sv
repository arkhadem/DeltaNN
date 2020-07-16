`include "sys_defs.svh"

module DeltaAcc(
	input clock,
	input clock_mem,
	input reset,

	// interface to DRAM controller slave
	input DRAM_slave_ChipSelect,
	input DRAM_slave_Read,
	input DRAM_slave_Write,
	input [3:0] DRAM_slave_Address,
	output [31:0] DRAM_slave_ReadData,
	input [31:0] DRAM_slave_WriteData,

	// interface to DRAM controller master
	input DRAM_master_WaitRequest,
	output reg DRAM_master_Read,
	output reg DRAM_master_Write,
	output reg[31:0] DRAM_master_Address,
	output reg[3:0] DRAM_master_ByteEnable,
	input[31:0] DRAM_master_ReadData,
	output reg[31:0] DRAM_master_WriteData
);

	//DeltaAcc Signals
	wire start;
	wire ack;	// to slave controller
	wire done;	// to slave controller
    wire [($clog2(`MAX_INPUT_CHANNEL) - 1) : 0] IC_Num;
    wire [($clog2(`MAX_OUTPUT_CHANNEL) - 1) : 0] OC_Num;

    wire [($clog2(`INPUT_CHANNEL) - 1) : 0] PU_IC_Num;
    wire [($clog2(`OUTPUT_CHANNEL) - 1) : 0] PU_OC_Num [(`PU_NUM - 1) : 0];

    wire [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] RC_Size;
    wire [($clog2(`MAX_FEATURE_SIZE) - 1) : 0] ORC_Size;
    wire [3 : 0] kernel_size;
    wire [2 : 0] stride;
    wire [1 : 0] AF_type;
    wire [1 : 0] Pool_type;
    wire [2 : 0] Pool_stride;
    wire [2 : 0] Pool_kernel_size;

    wire [($clog2(`MAX_WEIGHT_DELTA_LEN) - 1) : 0] weight_delta_len;
    wire [($clog2(`MAX_WEIGHT_NUM_LEN) - 1) : 0] weight_num_len;
    wire [($clog2(`MAX_IDX_DELTA_LEN) - 1) : 0] idx_delta_len;

    wire load_input;
	wire store_output;

    wire [31 : 0] weight_start_address;
    wire [31 : 0] weight_idx_start_offset;
    wire [31 : 0] weight_unique_start_offset;
    wire [31 : 0] weight_repetition_start_offset;
    wire [31 : 0] bias_start_address;
	wire [31 : 0] input_start_address;
	wire [31 : 0] output_start_address;

	wire DRAM_Read;
	wire DRAM_Write;
	wire[31:0] DRAM_Address;
	wire[31:0] DRAM_ReadData;
	wire[31:0] DRAM_WriteData;
	wire DRAM_DataReady;
	wire DRAM_WriteDone;

	wire [(`BIN_LEN - 1) : 0] inputs [(`INPUT_CHANNEL - 1) : 0][(`INPUT_HEIGHT - 1) : 0][(`INPUT_WIDTH - 1) : 0];

    wire [(`WEIGHT_SRAM_LEN - 1) : 0] WB_SRAM_in;
    wire [(`PU_NUM - 1) : 0] WB_SRAM_ready;
    wire [(`PU_NUM - 1) : 0] WB_SRAM_read;
    wire [31 : 0] WB_SRAM_address [(`PU_NUM - 1) : 0];

    wire [(`OUT_BIN_LEN - 1) : 0] OB_bias [(`PU_NUM - 1) : 0][(`OUTPUT_CHANNEL - 1) : 0];
    wire [(`OUTPUT_CHANNEL - 1) : 0] OB_w_enable [(`PU_NUM - 1) : 0];
    wire [(`OUTPUT_CHANNEL - 1) : 0] OB_r_enable [(`PU_NUM - 1) : 0];

    wire [((`BIN_LEN * `OUTPUT_SRAM_LEN) - 1) : 0] OB_SRAM_out;
    wire [($clog2(`OUTPUT_HEIGHT) - 1) : 0] OB_SRAM_r_out;
    wire [($clog2(`OUTPUT_WIDTH) - 1) : 0] OB_SRAM_c_out;


    wire [(`INPUT_CHANNEL - 1) : 0] IB_w_enable;
    wire [($clog2(`INPUT_HEIGHT) - 1) : 0] IB_SRAM_r;
    wire [($clog2(`INPUT_WIDTH) - 1) : 0] IB_SRAM_c;

    wire PU_start;
    wire [(`PU_NUM - 1) : 0] PU_finished;

    genvar PU_itr, IBuff_itr;

    // Input SRAM ports
    wire [127 : 0] Input_SRAM_w_d;
    wire [31 : 0] Input_SRAM_w_addr;
    wire [127 : 0] Input_SRAM_r_d;
    wire [31 : 0] Input_SRAM_r_addr;
    wire Input_SRAM_w_en;
    wire Input_SRAM_r_en;
    wire Input_SRAM_d_ready;
    wire Input_SRAM_w_done;

    // Output SRAM ports
    wire [63 : 0] Output_SRAM_w_d;
    wire [63 : 0] Output_SRAM_r_d;
    wire [31 : 0] Output_SRAM_w_addr;
    wire [31 : 0] Output_SRAM_r_addr;
    wire Output_SRAM_w_en;
    wire Output_SRAM_r_en;
    wire Output_SRAM_d_ready;
    wire Output_SRAM_w_done;

    // Weight SRAM ports
    wire [31 : 0] Weight_SRAM_w_d;
    wire [31 : 0] Weight_SRAM_r_d;
    wire [31 : 0] Weight_SRAM_addr;
    wire Weight_SRAM_w_en;
    wire Weight_SRAM_r_en;
    wire Weight_SRAM_d_ready;
    wire Weight_SRAM_w_done;

	DRAM_slave DRAM_slave_inst (
		//DRAM Signals
		.clock(clock),
		.reset(reset),
		.ChipSelect(DRAM_slave_ChipSelect),
		.Read(DRAM_slave_Read),
		.Write(DRAM_slave_Write),
		.Address(DRAM_slave_Address),
		.ReadData(DRAM_slave_ReadData),
		.WriteData(DRAM_slave_WriteData),

		//DeltaAcc Signals
		.start(start),
		.ack(ack),
		.done(done),
	    .IC_Num(IC_Num),
	    .OC_Num(OC_Num),

	    .RC_Size(RC_Size),
	    .ORC_Size(ORC_Size),
	    .kernel_size(kernel_size),
	    .stride(stride),
	    .AF_type(AF_type),
	    .Pool_type(Pool_type),
	    .Pool_stride(Pool_stride),
	    .Pool_kernel_size(Pool_kernel_size),

	    .weight_delta_len(weight_delta_len),
	    .weight_num_len(weight_num_len),
	    .idx_delta_len(idx_delta_len),

	    .load_input(load_input),
		.store_output(store_output),

	    .weight_start_address(weight_start_address),
	    .weight_idx_start_offset(weight_idx_start_offset),
	    .weight_unique_start_offset(weight_unique_start_offset),
	    .weight_repetition_start_offset(weight_repetition_start_offset),
		.bias_start_address(bias_start_address),
		.input_start_address(input_start_address),
		.output_start_address(output_start_address)
	);

	DRAM_master DRAM_master_inst(
		//DRAM Signals
		.clock(clock),
		.reset(reset),
		.WaitRequest(DRAM_master_WaitRequest),
		.Read(DRAM_master_Read),
		.Write(DRAM_master_Write),
		.Address(DRAM_master_Address),
		.ByteEnable(DRAM_master_ByteEnable),
		.ReadData(DRAM_master_ReadData),
		.WriteData(DRAM_master_WriteData),

		//DeltaAcc Calculator Signals
		.Acc_Read(DRAM_Read),
		.Acc_Write(DRAM_Write),
		.Acc_Address(DRAM_Address),
		.Acc_ReadData(DRAM_ReadData),
		.Acc_WriteData(DRAM_WriteData),
		.Acc_DataReady(DRAM_DataReady),
		.Acc_WriteDone(DRAM_WriteDone)
	);

    Input_SRAM_controller Input_SRAM_controller_inst(
    	.clock(clock_mem),
    	.reset(reset),

	    .w_d(Input_SRAM_w_d),
	    .w_addr(Input_SRAM_w_addr),
	    .r_d(Input_SRAM_r_d),
	    .r_addr(Input_SRAM_r_addr),
	    .w_en(Input_SRAM_w_en),
	    .r_en(Input_SRAM_r_en),
	    .d_ready(Input_SRAM_d_ready),
	    .w_done(Input_SRAM_w_done)
    );

    Output_SRAM_controller Output_SRAM_controller_inst(
    	.clock(clock_mem),
    	.reset(reset),

	    .w_d(Output_SRAM_w_d),
	    .w_addr(Output_SRAM_w_addr),
	    .r_d(Output_SRAM_r_d),
	    .r_addr(Output_SRAM_r_addr),
	    .w_en(Output_SRAM_w_en),
	    .r_en(Output_SRAM_r_en),
	    .d_ready(Output_SRAM_d_ready),
	    .w_done(Output_SRAM_w_done)
    );

    Weight_SRAM_controller Weight_SRAM_controller_inst(
    	.clock(clock_mem),
    	.reset(reset),

	    .addr(Weight_SRAM_addr),
	    .w_d(DRAM_ReadData),
	    .r_d(Weight_SRAM_r_d),
	    .w_en(Weight_SRAM_w_en),
	    .r_en(Weight_SRAM_r_en),
	    .d_ready(Weight_SRAM_d_ready),
	    .w_done(Weight_SRAM_w_done)
    );

    for (PU_itr = 0; PU_itr < `PU_NUM; PU_itr++) begin: processing_unit_generator
    	processing_unit processing_unit_inst(
	    	.clock(clock),
	        .reset(reset),
	        .start(PU_start),

	        // NN configuration
	        .inputs(inputs),
	        .stride(stride),
	        .AF_type(AF_type),
	        .Pool_type(Pool_type),
	        .Pool_stride(Pool_stride),
	        .Pool_kernel_size(Pool_kernel_size),

	        .weight_delta_len(weight_delta_len),
	        .weight_num_len(weight_num_len),
	        .idx_delta_len(idx_delta_len),
	        .IC_Num(PU_IC_Num),
	        .OC_Num(PU_OC_Num[PU_itr]),

	        // WB SRAM ports
	        .WB_SRAM_in(Weight_SRAM_r_d),
	        .WB_SRAM_ready(WB_SRAM_ready[PU_itr]),
	        .WB_SRAM_read(WB_SRAM_read[PU_itr]),
	        .WB_SRAM_address(WB_SRAM_address[PU_itr]),

	        // SRAM start address for each WB memory
	        .WB_SRAM_idx_start_address(weight_idx_start_offset),
	        .WB_SRAM_unique_start_address(weight_unique_start_offset),
	        .WB_SRAM_repetition_start_address(weight_repetition_start_offset),

	        // OB SRAM ports
	        .OB_bias(OB_bias[PU_itr]),
	        .OB_w_enable(OB_w_enable[PU_itr]),
	        .OB_r_enable(OB_r_enable[PU_itr]),
	        .OB_SRAM_out(OB_SRAM_out),
	        .OB_SRAM_r_out(OB_SRAM_r_out),
	        .OB_SRAM_c_out(OB_SRAM_c_out),

	        .finished(PU_finished[PU_itr])
    	);
    end


	for(IBuff_itr = 0; IBuff_itr < `INPUT_CHANNEL; IBuff_itr++) begin: input_buffer_generator

		Input_buffer Input_buffer_inst(
		    .clock(clock),

		    .w_enable(IB_w_enable[IBuff_itr]),


		    .SRAM_in(Input_SRAM_r_d),
		    .SRAM_r(IB_SRAM_r),
		    .SRAM_c(IB_SRAM_c),

		    .r_val(inputs[IBuff_itr])
		);

	end

	Delta_controller Delta_controller(
		.clock(clock),
		.reset(reset),

		//DeltaAcc Signals
		.start(start),
		.ack(ack),
		.done(done),

	    .IC_Num(IC_Num),
	    .OC_Num(OC_Num),
	    .RC_Size(RC_Size),
	    .ORC_Size(ORC_Size),

	    .kernel_size(kernel_size),
	    .stride(stride),

	    .weight_delta_len(weight_delta_len),
	    .weight_num_len(weight_num_len),
	    .idx_delta_len(idx_delta_len),

	    .load_input(load_input),
		.store_output(store_output),

		.weight_start_address(weight_start_address),
		.weight_idx_start_offset(weight_idx_start_offset),
		.weight_unique_start_offset(weight_unique_start_offset),
		.weight_repetition_start_offset(weight_repetition_start_offset),
		.bias_start_address(bias_start_address),
		.input_start_address(input_start_address),
		.output_start_address(output_start_address),

		// DRAM ports
		.DRAM_Read(DRAM_Read),
		.DRAM_Write(DRAM_Write),
		.DRAM_Address(DRAM_Address),
		.DRAM_ReadData(DRAM_ReadData),
		.DRAM_WriteData(DRAM_WriteData),
		.DRAM_DataReady(DRAM_DataReady),
		.DRAM_WriteDone(DRAM_WriteDone),

		// PU ports
	    // Output Buffer ports
	    .OB_bias(OB_bias),
	    .OB_w_enable(OB_w_enable),
	    .OB_r_enable(OB_r_enable),
	    .OB_SRAM_out(OB_SRAM_out),
	    .OB_SRAM_r_out(OB_SRAM_r_out),
	    .OB_SRAM_c_out(OB_SRAM_c_out),

	    // Input Buffer ports
	    .IB_w_enable(IB_w_enable),
	    .IB_SRAM_r(IB_SRAM_r),
	    .IB_SRAM_c(IB_SRAM_c),

	    // Weight Buffer ports
	    .WB_SRAM_ready(WB_SRAM_ready),
	    .WB_SRAM_read(WB_SRAM_read),
	    .WB_SRAM_address(WB_SRAM_address),

	    // Weight SRAM ports
	    .Weight_SRAM_addr(Weight_SRAM_addr),
	    .Weight_SRAM_w_en(Weight_SRAM_w_en),
	    .Weight_SRAM_r_en(Weight_SRAM_r_en),
	    .Weight_SRAM_d_ready(Weight_SRAM_d_ready),
	    .Weight_SRAM_w_done(Weight_SRAM_w_done),

	    // Input SRAM ports
	    .Input_SRAM_w_d(Input_SRAM_w_d),
	    .Input_SRAM_w_addr(Input_SRAM_w_addr),
	    .Input_SRAM_r_addr(Input_SRAM_r_addr),
	    .Input_SRAM_w_en(Input_SRAM_w_en),
	    .Input_SRAM_r_en(Input_SRAM_r_en),
	    .Input_SRAM_d_ready(Input_SRAM_d_ready),
	    .Input_SRAM_w_done(Input_SRAM_w_done),

	    // Output SRAM ports
	    .Output_SRAM_w_d(Output_SRAM_w_d),
	    .Output_SRAM_r_d(Output_SRAM_r_d),
	    .Output_SRAM_w_addr(Output_SRAM_w_addr),
	    .Output_SRAM_r_addr(Output_SRAM_r_addr),
	    .Output_SRAM_w_en(Output_SRAM_w_en),
	    .Output_SRAM_r_en(Output_SRAM_r_en),
	    .Output_SRAM_d_ready(Output_SRAM_d_ready),
	    .Output_SRAM_w_done(Output_SRAM_w_done),

	    // PU ports
	    .PU_start(PU_start),
		.PU_IC_Num(PU_IC_Num),
		.PU_OC_Num(PU_OC_Num),
		.PU_finished(PU_finished)
	);

endmodule