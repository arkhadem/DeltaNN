`include "sys_defs.svh"

module DRAM_master(
	//DRAM Signals
	input clock,
	input reset,
	input WaitRequest,
	output reg Read,
	output reg Write,
	output reg[31:0] Address,
	output reg[3:0] ByteEnable,
	input[31:0] ReadData,
	output reg[31:0] WriteData,

	//Magnitude Calculator Signals
	input Acc_Read,
	input Acc_Write,
	input[31:0] Acc_Address,
	output reg[31:0] Acc_ReadData,
	input[31:0] Acc_WriteData,
	output reg Acc_DataReady,
	output reg Acc_WriteDone
);

	parameter[2:0] Idle = 3'b000,	//Wait For Acc_Read or Acc_Write
					WFSR = 3'b001,	//Wait For Slave Read
					DR = 3'b010,	//Data Ready
					WFSW = 3'b011,	//Wait For Slave Write
					WD = 3'b100;	//Write Done
	reg[2:0] ps, ns;
	reg[31:0] my_Address, my_ReadData, my_WriteData;
	reg my_ReadRegEn, my_WriteRegEn;

	always@(posedge clock) begin
		if(reset == 1'b1)
			ps <= 3'b0;
		else
			ps <= ns;
	end

	always@(ps) begin
		Read <= 1'b0;
		Write <= 1'b0;
		Address <= 32'bz;
		ByteEnable <= 4'bz;
		WriteData <= 32'bz;
		Acc_ReadData <= 32'b0;
		Acc_DataReady <= 1'b0;
		Acc_WriteDone <= 1'b0;
		my_ReadRegEn <= 1'b0;
		my_WriteRegEn <= 1'b0;
		case(ps)
			Idle: begin

				my_WriteRegEn <= 1'b1;
			end
			WFSR: begin
				Read <= 1'b1;
				ByteEnable <= 4'b1111;
				Address <= my_Address;
				my_ReadRegEn <= 1'b1;
			end
			DR: begin
				Acc_ReadData <= my_ReadData;
				Acc_DataReady <= 1'b1;
			end
			WFSW: begin
				Write <= 1'b1;
				ByteEnable <= 4'b1111;
				Address <= my_Address;
				WriteData <= my_WriteData;
			end
			WD: begin
				Acc_WriteDone <= 1'b1;
			end
			default: begin
				Read <= 1'b0;
				Write <= 1'b0;
				Address <= 32'bz;
				ByteEnable <= 4'bz;
				WriteData <= 32'bz;
				Acc_ReadData <= 32'b0;
				Acc_DataReady <= 1'b0;
				Acc_WriteDone <= 1'b0;
				my_ReadRegEn <= 1'b0;
				my_WriteRegEn <= 1'b0;
			end
		endcase
	end

	always@(ps, Acc_Read, Acc_Write, WaitRequest) begin
		ns <= Idle;
		case(ps)
			Idle: begin
				if(Acc_Read == 1'b1) begin
					ns <= WFSR;
				end else if(Acc_Write == 1'b1) begin
					ns <= WFSW;
				end else begin
					ns <= Idle;
				end
			end
			WFSR: begin
				if(WaitRequest == 1'b1) begin
					ns <= WFSR;
				end else begin
					ns <= DR;
				end
			end
			DR: begin
				ns <= Idle;
			end
			WFSW: begin
				if(WaitRequest == 1'b1) begin
					ns <= WFSW;
				end else begin
					ns <= WD;
				end
			end
			WD: begin
				ns <= Idle;
			end
			default: begin
				ns <= Idle;
			end
		endcase
	end

	always@(posedge clock) begin
		if(reset) begin
			my_ReadData <= 32'b0;
		end else if(my_ReadRegEn == 1'b1) begin
			my_ReadData <= ReadData;
		end
	end

	always@(posedge clock) begin
		if(reset) begin
			my_WriteData <= 32'b0;
			my_Address <= 32'b0;
		end else if(my_WriteRegEn == 1'b1) begin
			my_Address <= Acc_Address;
			my_WriteData <= Acc_WriteData;
		end
	end


endmodule