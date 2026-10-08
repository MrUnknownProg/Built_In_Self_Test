`timescale 1ns / 1ps

module fault_addr_lfsr #(
    parameter WIDTH      = 8,
    parameter NUM_FAULTS = 8,
    parameter [WIDTH-1:0] SEED = 8'h01
)(
    input wire clk_i,
    input wire rst_i,

    input wire generate_i,

    output reg [NUM_FAULTS*WIDTH-1:0] fault_addr_o,

    output reg valid_o
);

    reg [WIDTH-1:0] lfsr_reg;

    reg [3:0] count;

    reg busy;

    wire feedback;

    assign feedback = lfsr_reg[7] ^ lfsr_reg[5] ^ lfsr_reg[4] ^ lfsr_reg[3];

    always @(posedge clk_i) begin

        if (rst_i) begin

            lfsr_reg <= SEED;

            count <= 4'd0;

            busy <= 1'b0;

            valid_o <= 1'b0;

            fault_addr_o <= {(NUM_FAULTS*WIDTH){1'b0}};

        end

        else begin

            valid_o <= 1'b0;

            if (generate_i && !busy) begin

                lfsr_reg <= SEED;

                count <= 4'd0;

                busy <= 1'b1;

                fault_addr_o <= {(NUM_FAULTS*WIDTH){1'b0}};

            end

            else if (busy) begin

                case (count)

                    4'd0: fault_addr_o[7:0] <= lfsr_reg;

                    4'd1: fault_addr_o[15:8] <= lfsr_reg;

                    4'd2: fault_addr_o[23:16] <= lfsr_reg;

                    4'd3: fault_addr_o[31:24] <= lfsr_reg;

                    4'd4: fault_addr_o[39:32] <= lfsr_reg;

                    4'd5: fault_addr_o[47:40] <= lfsr_reg;

                    4'd6: fault_addr_o[55:48] <= lfsr_reg;

                    4'd7: fault_addr_o[63:56] <= lfsr_reg;

                    default:
                        begin
                        end

                endcase

                lfsr_reg <= {lfsr_reg[6:0], feedback};

                if (count == NUM_FAULTS-1) begin

                    busy <= 1'b0;

                    valid_o <= 1'b1;

                end

                else begin

                    count <= count + 4'd1;

                end

            end

        end

    end

endmodule
