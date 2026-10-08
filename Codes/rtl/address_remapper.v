`timescale 1ns / 1ps

module address_remapper #(
    parameter ADDR_WIDTH = 10
)(
    input wire [ADDR_WIDTH-1:0] logical_addr_i,

    input wire [ADDR_WIDTH-1:0] repair_addr_i,

    input wire repair_valid_i,

    output wire [ADDR_WIDTH-1:0] physical_addr_o
);

    assign physical_addr_o = repair_valid_i ? repair_addr_i : logical_addr_i;

endmodule
