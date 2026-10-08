`timescale 1ns / 1ps

module fault_order_capture #(
    parameter NUM_FAULTS = 8
)(
    input wire                     clk_i,
    input wire                     rst_i,
    input wire                     repair_reset_i,

    input wire [NUM_FAULTS-1:0]    fault_switch_i,

    output reg [NUM_FAULTS-1:0]    active_faults_o,

    output reg [23:0]              fault_order_o,

    output reg [3:0]               fault_order_count_o
);

    reg [NUM_FAULTS-1:0] previous_switches;

    integer i;

    always @(posedge clk_i or posedge rst_i) begin

        if (rst_i) begin

            previous_switches   <= {NUM_FAULTS{1'b0}};
            active_faults_o     <= {NUM_FAULTS{1'b0}};
            fault_order_o       <= 24'd0;
            fault_order_count_o <= 4'd0;

        end

        else if (repair_reset_i) begin

            previous_switches   <= {NUM_FAULTS{1'b0}};
            active_faults_o     <= {NUM_FAULTS{1'b0}};
            fault_order_o       <= 24'd0;
            fault_order_count_o <= 4'd0;

        end

        else begin

            /*
             * Detect rising edges of the physical switches.
             *
             * If switches are activated at different times:
             *
             * SW5 -> SW2 -> SW7 -> SW3 -> SW1
             *
             * the captured order is:
             *
             * 5 -> 2 -> 7 -> 3 -> 1
             */

            for (i = 0; i < NUM_FAULTS; i = i + 1) begin

                if (fault_switch_i[i] &&
                    !previous_switches[i] &&
                    !active_faults_o[i] &&
                    (fault_order_count_o < NUM_FAULTS)) begin

                    active_faults_o[i] <= 1'b1;

                    case (fault_order_count_o)

                        4'd0:
                            fault_order_o[2:0] <= i[2:0];

                        4'd1:
                            fault_order_o[5:3] <= i[2:0];

                        4'd2:
                            fault_order_o[8:6] <= i[2:0];

                        4'd3:
                            fault_order_o[11:9] <= i[2:0];

                        4'd4:
                            fault_order_o[14:12] <= i[2:0];

                        4'd5:
                            fault_order_o[17:15] <= i[2:0];

                        4'd6:
                            fault_order_o[20:18] <= i[2:0];

                        4'd7:
                            fault_order_o[23:21] <= i[2:0];

                        default:
                            begin
                            end

                    endcase

                    fault_order_count_o <=
                        fault_order_count_o + 4'd1;

                end

            end

            /*
             * Store current switch state for
             * rising-edge detection.
             */

            previous_switches <= fault_switch_i;

        end

    end

endmodule