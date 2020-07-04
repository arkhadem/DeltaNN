module Weight_SRAM_controller (
	input clock,
	input reset,

    input [31 : 0] addr,

    input [31 : 0] w_d,
    output [31 : 0] r_d,
    input w_en,
    input r_en,
    output reg d_ready,
    output reg w_done
);
    
    genvar row_itr;

    reg write_in_progress;
    reg read_in_progress;

    reg [24 : 0] chip_select;
    reg [24 : 0] write_enable;

    wire [31 : 0] data_out [24 : 0];

    reg [4 : 0] row_turn;

    for (row_itr = 0; row_itr < 25; row_itr++) begin: Weight_SRAM_banks
        sram_32_2048_scn4m_subm sram_32_2048_scn4m_subm_inst(
            .clk0(clock),
            .csb0(~chip_select[row_itr]),
            .web0(~write_enable[row_itr]),
            .addr0(addr[10 : 0]),
            .din0(w_d),
            .dout0(data_out[row_itr])
        );
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
                chip_select[addr[15 : 11]] = 1;
                write_enable[addr[15 : 11]] = 1;
                row_turn = addr[15 : 11];
            end else if(r_en == 1) begin
                read_in_progress = 1;
                chip_select[addr[15 : 11]] = 1;
                write_enable[addr[15 : 11]] = 0;
                row_turn = addr[15 : 11];
            end else begin
                write_in_progress = 0;
                read_in_progress = 0;
                chip_select = 0;
                write_enable = 0;
            end
        end
    end

endmodule
