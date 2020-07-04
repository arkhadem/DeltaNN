`include "sys_defs.svh"

module DeltaAcc_test();

	reg clock;
	reg clock_mem;
	reg reset;

	// DRAM ports
	reg DRAM_slave_ChipSelect;
	reg DRAM_slave_Read;
	reg DRAM_slave_Write;
	reg [3:0] DRAM_slave_Address;
	wire [31:0] DRAM_slave_ReadData;
	reg [31:0] DRAM_slave_WriteData;

	reg DRAM_master_WaitRequest;
	wire DRAM_master_Read;
	wire DRAM_master_Write;
	wire [31:0] DRAM_master_Address;
	wire [3:0] DRAM_master_ByteEnable;
	reg [31:0] DRAM_master_ReadData;
	wire [31:0] DRAM_master_WriteData;


	DeltaAcc UUT(
		.clock(clock),
		.clock_mem(clock_mem),
		.reset(reset),

		// interface to DRAM controller slave
		.DRAM_slave_ChipSelect(DRAM_slave_ChipSelect),
		.DRAM_slave_Read(DRAM_slave_Read),
		.DRAM_slave_Write(DRAM_slave_Write),
		.DRAM_slave_Address(DRAM_slave_Address),
		.DRAM_slave_ReadData(DRAM_slave_ReadData),
		.DRAM_slave_WriteData(DRAM_slave_WriteData),

		// interface to DRAM controller master
		.DRAM_master_WaitRequest(DRAM_master_WaitRequest),
		.DRAM_master_Read(DRAM_master_Read),
		.DRAM_master_Write(DRAM_master_Write),
		.DRAM_master_Address(DRAM_master_Address),
		.DRAM_master_ByteEnable(DRAM_master_ByteEnable),
		.DRAM_master_ReadData(DRAM_master_ReadData),
		.DRAM_master_WriteData(DRAM_master_WriteData)
	);

endmodule