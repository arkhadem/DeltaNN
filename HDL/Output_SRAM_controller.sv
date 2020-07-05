module Output_SRAM_controller (
	input clock,
	input reset,

    input [31 : 0] w_addr,
    input [63 : 0] w_d,
    input [31 : 0] r_addr,
    output [63 : 0] r_d,
    input w_en,
    input r_en,
    output reg d_ready,
    output reg w_done
);
    
    genvar column_itr, row_itr;

    reg write_in_progress;
    reg read_in_progress;

    reg [5 : 0] chip_select;
    reg [5 : 0] write_enable;

    wire [10 : 0] chip_address;

    wire [63 : 0] data_out [5 : 0];

    reg [2 : 0] row_turn;

    assign chip_address = (write_enable[row_turn] == 1) ? w_addr[10 : 0] : r_addr[10 : 0];

    for (row_itr = 0; row_itr < 6; row_itr++) begin: Output_SRAM_banks_row
        for (column_itr = 0; column_itr < 2; column_itr++) begin: Output_SRAM_banks_column
            sram_32_2048_scn4m_subm sram_32_2048_scn4m_subm_inst(
                .clk0(clock),
                .csb0(~chip_select[row_itr]),
                .web0(~write_enable[row_itr]),
                .addr0(chip_address),
                .din0(w_d[(((column_itr + 1) << 5) - 1) : (column_itr << 5)]),
                .dout0(data_out[row_itr][(((column_itr + 1) << 5) - 1) : (column_itr << 5)])
            );
        end
    end

    assign r_d = data_out[row_turn];

    always@(posedge clock) begin
        if(reset) begin
            chip_select = 0;
            write_enable = 0;
            write_in_progress = 0;
            read_in_progress = 0;
            d_ready = 0;
            w_done = 0;
            row_turn = 0;
        end else begin
            if(write_in_progress == 1) begin
                write_in_progress = 0;
                w_done = 1;
            end else begin
                w_done = 0;
            end
            if(read_in_progress == 1) begin
                read_in_progress = 0;
                d_ready = 1;
            end else begin
                d_ready = 0;
            end
            if(w_en == 1) begin
                write_in_progress = 1;
                chip_select[w_addr[13 : 11]] = 1;
                write_enable[w_addr[13 : 11]] = 1;
                row_turn = w_addr[13 : 11];
            end else if(r_en == 1) begin
                read_in_progress = 1;
                chip_select[r_addr[13 : 11]] = 1;
                write_enable[r_addr[13 : 11]] = 0;
                row_turn = r_addr[13 : 11];
            end else begin
                write_in_progress = 0;
                read_in_progress = 0;
                chip_select = 0;
                write_enable = 0;
            end
        end
    end

endmodule
