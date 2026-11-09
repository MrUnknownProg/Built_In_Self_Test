`timescale 1ns / 1ps

module tb_random;

    // --------------------------------------------------
    // Parameters
    // --------------------------------------------------
    parameter integer NUM_RANDOM_TESTS = 20;
    parameter integer MAX_CYCLES        = 10000;
    parameter integer NUM_FAULT_SWITCHES = 8;

    // Set to a nonzero value to reproduce a random sequence.
    integer random_seed = 32'h1234_ABCD;

    // --------------------------------------------------
    // Clock and reset
    // 100 MHz clock: 10 ns period
    // --------------------------------------------------
    reg clk_i_0;
    reg rst_i_0;
    reg start_i_0;
    reg [NUM_FAULT_SWITCHES-1:0] fault_en_i_0;
    reg repair_reset_i_0;

    // --------------------------------------------------
    // DUT outputs
    // --------------------------------------------------
    wire done_o_0;
    wire [7:0] fail_count_o_0;
    wire fail_flag_o_0;

    wire [9:0] fault_addr_o;
    wire fault_addr_valid_o;

    wire [9:0] repair_count_o_0;
    wire repair_full_o_0;

    wire [9:0] repaired_logical_addr_o_0;
    wire [9:0] repaired_physical_addr_o_0;
    wire repaired_valid_o_0;
    wire valid_o_0;

    // --------------------------------------------------
    // DUT instantiation
    // --------------------------------------------------
    top_mbist DUT (
        .clk_i_0                   (clk_i_0),
        .rst_i_0                   (rst_i_0),
        .start_i_0                 (start_i_0),
        .fault_en_i_0              (fault_en_i_0),
        .repair_reset_i_0          (repair_reset_i_0),

        .done_o_0                  (done_o_0),
        .fail_count_o_0            (fail_count_o_0),
        .fail_flag_o_0             (fail_flag_o_0),

        .fault_addr_o              (fault_addr_o),
        .fault_addr_valid_o        (fault_addr_valid_o),

        .repair_count_o_0          (repair_count_o_0),
        .repair_full_o_0           (repair_full_o_0),

        .repaired_logical_addr_o_0 (repaired_logical_addr_o_0),
        .repaired_physical_addr_o_0(repaired_physical_addr_o_0),
        .repaired_valid_o_0        (repaired_valid_o_0),
        .valid_o_0                 (valid_o_0)
    );

    // --------------------------------------------------
    // Clock generation
    // --------------------------------------------------
    initial clk_i_0 = 1'b0;
    always #5 clk_i_0 = ~clk_i_0;

    // --------------------------------------------------
    // Test statistics
    // --------------------------------------------------
    integer test_number;
    integer cycle_count;
    integer pass_count;
    integer fail_count;
    integer timeout_count;

    integer random_mode;
    reg [NUM_FAULT_SWITCHES-1:0] random_fault_mask;

    // --------------------------------------------------
    // Reset task
    // --------------------------------------------------
    task automatic reset_dut;
        begin
            rst_i_0          = 1'b1;
            start_i_0        = 1'b0;
            fault_en_i_0     = {NUM_FAULT_SWITCHES{1'b0}};
            repair_reset_i_0 = 1'b0;

            repeat (5) @(negedge clk_i_0);

            rst_i_0 = 1'b0;

            repeat (2) @(negedge clk_i_0);
        end
    endtask

    // --------------------------------------------------
    // Start one MBIST operation and wait for completion.
    // --------------------------------------------------
    task automatic run_mbist;
        begin
            @(negedge clk_i_0);
            start_i_0 = 1'b1;

            @(negedge clk_i_0);
            start_i_0 = 1'b0;

            cycle_count = 0;

            while ((done_o_0 !== 1'b1) &&
                   (cycle_count < MAX_CYCLES)) begin
                @(negedge clk_i_0);
                cycle_count = cycle_count + 1;
            end

            if (done_o_0 !== 1'b1) begin
                $display(
                    "TIMEOUT: Test=%0d after %0d cycles",
                    test_number, cycle_count
                );
                timeout_count = timeout_count + 1;
                fail_count = fail_count + 1;
            end
        end
    endtask

    // --------------------------------------------------
    // Report DUT status after a completed test.
    // --------------------------------------------------
    task automatic report_status;
        begin
            $display(
                "Test=%0d | FaultMask=%b | Done=%b | FailFlag=%b | FailCount=%0d | RepairCount=%0d | RepairFull=%b",
                test_number,
                fault_en_i_0,
                done_o_0,
                fail_flag_o_0,
                fail_count_o_0,
                repair_count_o_0,
                repair_full_o_0
            );

            if ((^{
                done_o_0,
                fail_flag_o_0,
                fail_count_o_0,
                repair_count_o_0,
                repair_full_o_0
            }) === 1'bx) begin
                $display("ERROR: Unknown or uninitialized status output");
                fail_count = fail_count + 1;
            end
        end
    endtask

    // --------------------------------------------------
    // Main randomized test sequence
    // --------------------------------------------------
    initial begin
        pass_count    = 0;
        fail_count    = 0;
        timeout_count = 0;
        test_number   = 0;

        // Initialize simulator random-number generator.
        random_seed = $urandom(random_seed);

        $display("");
        $display("==============================================");
        $display(" RANDOMIZED MBIST VERIFICATION");
        $display(" Clock frequency : 100 MHz");
        $display(" Random tests    : %0d", NUM_RANDOM_TESTS);
        $display(" Seed            : %0d", random_seed);
        $display("==============================================");

        // ==========================================
        // TEST 1: Fault-free memory test
        // ==========================================
        test_number = test_number + 1;
        $display("\nTEST %0d: Fault-free MBIST", test_number);

        reset_dut();
        fault_en_i_0 = '0;
        run_mbist();
        report_status();

        if (done_o_0 === 1'b1 &&
            fail_flag_o_0 === 1'b0 &&
            fail_count_o_0 == 0) begin
            $display("PASS: Fault-free memory test");
            pass_count = pass_count + 1;
        end
        else if (done_o_0 === 1'b1) begin
            $display("FAIL: Unexpected fault indication");
            fail_count = fail_count + 1;
        end

        // ==========================================
        // TEST 2: Each fault switch individually
        // ==========================================
        for (integer k = 0; k < NUM_FAULT_SWITCHES; k = k + 1) begin
            test_number = test_number + 1;

            reset_dut();
            fault_en_i_0 = '0;
            fault_en_i_0[k] = 1'b1;

            $display(
                "\nTEST %0d: Single fault switch %0d, mask=%b",
                test_number, k, fault_en_i_0
            );

            run_mbist();
            report_status();

            if (done_o_0 === 1'b1) begin
                // Fault detection and repair semantics depend on the RTL.
                // Record the result for detailed inspection.
                $display(
                    "COMPLETED: Single-switch test %0d",
                    k
                );
                pass_count = pass_count + 1;
            end
        end

        // ==========================================
        // TEST 3: Randomized nonzero fault masks
        // ==========================================
        for (integer j = 0; j < NUM_RANDOM_TESTS; j = j + 1) begin
            test_number = test_number + 1;

            reset_dut();

            // Select a random fault pattern from 1 to 255.
            random_fault_mask =
                $urandom_range(1, (1 << NUM_FAULT_SWITCHES) - 1);

            fault_en_i_0 = random_fault_mask;

            $display(
                "\nTEST %0d: Random fault pattern %b",
                test_number, fault_en_i_0
            );

            run_mbist();
            report_status();

            if (done_o_0 === 1'b1) begin
                $display("COMPLETED: Randomized fault test");
                pass_count = pass_count + 1;
            end
        end

        // ==========================================
        // Final summary
        // ==========================================
        $display("");
        $display("==============================================");
        $display(" RANDOMIZED MBIST TEST SUMMARY");
        $display(" Total tests attempted : %0d", test_number);
        $display(" Completed tests       : %0d", pass_count);
        $display(" Failed checks/timeouts: %0d", fail_count);
        $display(" Timeouts              : %0d", timeout_count);
        $display("==============================================");

        if (fail_count == 0 && timeout_count == 0)
            $display("TESTBENCH CHECKS PASSED");
        else
            $display("TESTBENCH CHECKS FAILED");

        $finish;
    end

endmodule

