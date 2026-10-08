`timescale 1ns / 1ps

module data_gen #(
    parameter DATA_WIDTH = 32
)(
    input wire [1:0] pattern_sel_i,

    output reg [DATA_WIDTH-1:0] data_o
);

    always @(*) begin

        case (pattern_sel_i)

            2'b00: data_o = {DATA_WIDTH{1'b0}};

            2'b01: data_o = {DATA_WIDTH{1'b1}};

            2'b10: data_o = {DATA_WIDTH/2{2'b10}};

            2'b11: data_o = {DATA_WIDTH/2{2'b01}};

            default: data_o = {DATA_WIDTH{1'b0}};

        endcase

    end

endmodule