`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.04.2026 10:18:08
// Design Name: 
// Module Name: tb_lfsr
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_lfsr();

    parameter WIDTH = 8;
    parameter SEED  = 8'h1;

    reg clk_i;
    reg rst_i;
    reg en_i;
    wire [WIDTH-1:0] data_o;

    // Instantiate DUT
    lfsr #(
        .WIDTH(WIDTH),
        .SEED(SEED)
    ) u_dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .en_i(en_i),
        .data_o(data_o)
    );

    // Clock Generation (10ns period)
    always #5 clk_i = ~clk_i;

    integer i;

    initial begin
        $display("===== LFSR TEST START =====");

        clk_i = 0;
        rst_i = 1;
        en_i  = 0;

        // Apply reset
        #10;
        rst_i = 0;

        // Check seed load
        #10;
        if (data_o == SEED)
            $display("PASS: Seed loaded correctly = %b", data_o);
        else
            $display("FAIL: Seed incorrect = %b", data_o);

        // Enable LFSR
        en_i = 1;

        // Run for multiple cycles
        for (i = 0; i < 20; i = i + 1) begin
            #10;
            $display("Cycle %0d: LFSR Output = %b", i, data_o);
        end

        // Disable and check hold
        en_i = 0;
        #10;
        $display("LFSR HOLD CHECK = %b", data_o);

        #20;

        $display("===== TEST COMPLETE =====");
        $finish;
    end

endmodule
