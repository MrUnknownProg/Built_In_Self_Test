`timescale 1ns / 1ps

module fault_inject #(
    parameter DATA_WIDTH       = 32,
    parameter ADDR_WIDTH       = 10,
    parameter NUM_FAULTS       = 8,
    parameter FAULT_ADDR_WIDTH = 8
)(
    input wire [DATA_WIDTH-1:0]
        data_i,

    input wire [ADDR_WIDTH-1:0]
        addr_i,

    input wire [NUM_FAULTS-1:0]
        fault_en_i,

    input wire [NUM_FAULTS*FAULT_ADDR_WIDTH-1:0]
        fault_addr_i,

    output reg [DATA_WIDTH-1:0]
        data_o,

    output reg
        fault_hit_o,

    output reg [2:0]
        fault_id_o
);

    integer i;

    always @(*) begin

        data_o      = data_i;
        fault_hit_o = 1'b0;
        fault_id_o  = 3'd0;

        for (i = 0; i < NUM_FAULTS; i = i + 1) begin

            if (!fault_hit_o &&
                fault_en_i[i] &&
                (addr_i[FAULT_ADDR_WIDTH-1:0] ==
                 fault_addr_i[
                     i*FAULT_ADDR_WIDTH +
                     : FAULT_ADDR_WIDTH
                 ])) begin

                data_o =
                    ~data_i;

                fault_hit_o =
                    1'b1;

                fault_id_o =
                    i[2:0];

            end

        end

    end

endmodule