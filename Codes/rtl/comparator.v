`timescale 1ns / 1ps

module comparator #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)(
    input wire clk_i,

    input wire rst_i,

    input wire compare_en_i,

    input wire [DATA_WIDTH-1:0] expected_data_i,

    input wire [DATA_WIDTH-1:0] read_data_i,

    input wire [ADDR_WIDTH-1:0] addr_i,

    input wire [2:0] fault_id_i,

    output reg fail_flag_o,

    output reg [7:0] fail_count_o,

    output reg [ADDR_WIDTH-1:0] fault_addr_o,

    output reg fault_addr_valid_o,

    output reg [2:0] fault_id_o
);

    always @(posedge clk_i) begin

        if (rst_i) begin

            fail_flag_o = 1'b0;

            fail_count_o = 8'd0;

            fault_addr_o = {ADDR_WIDTH{1'b0}};

            fault_addr_valid_o = 1'b0;

            fault_id_o = 3'd0;

        end

        else begin

            // One-cycle pulse
            fault_addr_valid_o <= 1'b0;

            if (compare_en_i) begin

                if (read_data_i != expected_data_i) begin

                    fail_flag_o <= 1'b1;

                    if (fail_count_o != 8'hFF) begin

                        fail_count_o <= fail_count_o + 8'd1;

                    end

                    fault_addr_o <= addr_i;

                    fault_addr_valid_o <= 1'b1;

                    fault_id_o <= fault_id_i;

                end

            end

        end

    end

endmodule
