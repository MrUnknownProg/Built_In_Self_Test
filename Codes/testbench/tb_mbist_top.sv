
`timescale 1ns / 1ps

module tb_mbist_top;

    // =========================================================
    // PARAMETERS
    // =========================================================
    localparam ADDR_WIDTH       = 10;
    localparam NUM_FAULTS       = 8;
    localparam DEPTH            = 1024;
    localparam SPARE_START      = 256;
    localparam TIMEOUT_CYCLES   = 3000;
    localparam NUM_RANDOM_TESTS = 20;

    // =========================================================
    // CLOCK
    // 100 MHz: 10 ns period
    // =========================================================
    logic clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================
    // INTERFACE
    // =========================================================
    mbist_if #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .NUM_FAULTS (NUM_FAULTS),
        .DEPTH      (DEPTH),
        .SPARE_START(SPARE_START)
    ) mif (.clk(clk));

    // =========================================================
    // DUT INSTANTIATION
    // =========================================================
    top_mbist dut (
        .clk_i_0                    (mif.clk),
        .rst_i_0                    (mif.rst),
        .start_i_0                  (mif.start),
        .fault_switch_i_0           (mif.fault_switch),
        .repair_reset_i_0           (mif.repair_reset),

        .done_o_0                   (mif.done),
        .fail_flag_o_0              (mif.fail_flag),
        .fail_count_o_0             (mif.fail_count),
        .fault_addr_o               (mif.fault_addr),
        .fault_addr_valid_o         (mif.fault_addr_valid),
        .fault_hit_o_0              (mif.fault_hit),
        .valid_o_0                  (mif.valid),
        .repair_count_o_0            (mif.repair_count),
        .repair_full_o_0             (mif.repair_full),
        .repaired_logical_addr_o_0  (mif.repaired_logical_addr),
        .repaired_physical_addr_o_0 (mif.repaired_physical_addr),
        .repaired_valid_o_0          (mif.repaired_valid)
    );

    // =========================================================
    // TEST VARIABLES
    // =========================================================
    integer pass_cnt;
    integer fail_cnt;
    integer test_id;
    integer random_seed = 32'h1234_ABCD;

    integer cur_faults[$];

    integer observed_repairs;
    logic [ADDR_WIDTH-1:0] observed_logical  [0:NUM_FAULTS-1];
    logic [ADDR_WIDTH-1:0] observed_physical [0:NUM_FAULTS-1];

    // =========================================================
    // CAPTURE REPAIR EVENTS
    // =========================================================
    always @(posedge clk) begin
        if (mif.repaired_valid === 1'b1) begin
            if (observed_repairs < NUM_FAULTS) begin
                observed_logical[observed_repairs] =
                    mif.repaired_logical_addr;

                observed_physical[observed_repairs] =
                    mif.repaired_physical_addr;

                observed_repairs = observed_repairs + 1;
            end

            $display(
                "[%0t] REPAIR: logical=%0d -> physical=%0d",
                $time,
                mif.repaired_logical_addr,
                mif.repaired_physical_addr
            );
        end
    end

    // =========================================================
    // SELF-CHECKING TASK
    // =========================================================
    task automatic check(
        input string name,
        input logic condition
    );
        begin
            if (condition === 1'b1) begin
                pass_cnt = pass_cnt + 1;
                $display("PASS: %s", name);
            end
            else begin
                fail_cnt = fail_cnt + 1;
                $display("FAIL: %s", name);
            end
        end
    endtask

    // =========================================================
    // CLEAR REPAIR LOG
    // =========================================================
    task automatic clear_repair_log;
        integer i;
        begin
            observed_repairs = 0;

            for (i = 0; i < NUM_FAULTS; i = i + 1) begin
                observed_logical[i]  = '0;
                observed_physical[i] = '0;
            end
        end
    endtask

    // =========================================================
    // CLEAR SWITCHES
    // =========================================================
    task automatic clear_switches;
        begin
            @(negedge clk);
            mif.fault_switch = '0;
            repeat (2) @(posedge clk);
        end
    endtask

    // =========================================================
    // MBIST RESET
    // =========================================================
    task automatic do_mbist_reset;
        begin
            @(negedge clk);
            mif.rst = 1'b1;
            repeat (3) @(posedge clk);

            @(negedge clk);
            mif.rst = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    // =========================================================
    // REPAIR RESET
    // =========================================================
    task automatic do_repair_reset;
        begin
            @(negedge clk);
            mif.repair_reset = 1'b1;
            repeat (3) @(posedge clk);

            @(negedge clk);
            mif.repair_reset = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    // =========================================================
    // FULL RESET
    // =========================================================
    task automatic full_repair_reset;
        begin
            clear_switches();
            do_repair_reset();
            do_mbist_reset();
            clear_repair_log();
        end
    endtask

    // =========================================================
    // ACTIVATE SWITCH IN ORDER
    // =========================================================
    task automatic set_switch(input integer index);
        begin
            @(negedge clk);
            mif.fault_switch[index] = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    // =========================================================
    // START MBIST
    // =========================================================
    task automatic pulse_start;
        begin
            @(negedge clk);
            mif.start = 1'b1;

            @(negedge clk);
            mif.start = 1'b0;
        end
    endtask

    // =========================================================
    // WAIT FOR COMPLETION
    // =========================================================
    task automatic wait_done(output bit completed);
        integer cycles;
        begin
            completed = 1'b0;
            cycles = 0;

            while ((cycles < TIMEOUT_CYCLES) &&
                   (completed == 1'b0)) begin

                @(negedge clk);
                cycles = cycles + 1;

                if (mif.done === 1'b1)
                    completed = 1'b1;
            end

            if (!completed) begin
                $display("ERROR: MBIST timeout");
            end
            else begin
                // Allow the repair controller to finish.
                repeat (NUM_FAULTS + 2) @(posedge clk);
            end
        end
    endtask

    // =========================================================
    // RUN MBIST USING cur_faults
    // =========================================================
    task automatic run_mbist;
        integer i;
        bit completed;
        begin
            clear_switches();
            do_mbist_reset();

            for (i = 0; i < cur_faults.size(); i = i + 1)
                set_switch(cur_faults[i]);

            pulse_start();
            wait_done(completed);

            check("MBIST completed without timeout", completed);
        end
    endtask

    // =========================================================
    // VERIFY A REPAIR MAPPING
    // =========================================================
    task automatic check_repair_pair(
        input integer index,
        input logic [ADDR_WIDTH-1:0] expected_logical,
        input logic [ADDR_WIDTH-1:0] expected_physical,
        input string name
    );
        begin
            if (index < observed_repairs) begin
                check(
                    {name, " logical address"},
                    observed_logical[index] === expected_logical
                );

                check(
                    {name, " physical address"},
                    observed_physical[index] === expected_physical
                );
            end
            else begin
                check({name, " repair event exists"}, 1'b0);
            end
        end
    endtask

    // =========================================================
    // RANDOMIZED TEST
    // Random unique switches in randomized activation order.
    // =========================================================
    task automatic randomized_test(input integer id);
        integer n;
        integer candidate;
        integer i;
        integer j;
        bit duplicate;

        begin
            test_id = id;
            cur_faults.delete();

            n = $urandom_range(1, NUM_FAULTS);

            while (cur_faults.size() < n) begin
                candidate = $urandom_range(0, NUM_FAULTS-1);
                duplicate = 1'b0;

                for (j = 0; j < cur_faults.size(); j = j + 1) begin
                    if (cur_faults[j] == candidate)
                        duplicate = 1'b1;
                end

                if (!duplicate)
                    cur_faults.push_back(candidate);
            end

            $display("\n--- RANDOM TEST %0d ---", id);
            $display("Fault count = %0d", n);

            for (i = 0; i < cur_faults.size(); i = i + 1) begin
                $display(
                    "Activation order[%0d] = switch %0d",
                    i, cur_faults[i]
                );
            end

            full_repair_reset();
            run_mbist();

            check(
                $sformatf("Random %0d failure count", id),
                mif.fail_count == n
            );

            check(
                $sformatf("Random %0d repair count", id),
                mif.repair_count == n
            );

            check(
                $sformatf("Random %0d repair events", id),
                observed_repairs == n
            );
        end
    endtask

    // =========================================================
    // MAIN TEST SEQUENCE
    // =========================================================
    initial begin : main_test
        integer r;
        integer seed_result;

        pass_cnt = 0;
        fail_cnt = 0;
        test_id = 0;
        observed_repairs = 0;

        mif.rst = 1'b0;
        mif.start = 1'b0;
        mif.fault_switch = '0;
        mif.repair_reset = 1'b0;

        seed_result = $urandom(random_seed);

        $display("======================================");
        $display(" RANDOMIZED MBIST TESTBENCH");
        $display(" Clock frequency = 100 MHz");
        $display(" Random seed = %0d", random_seed);
        $display("======================================");

        full_repair_reset();

        // -----------------------------------------------------
        // TEST 1: FAULT-FREE MBIST
        // -----------------------------------------------------
        $display("\n--- TEST 1: FAULT-FREE MBIST ---");

        cur_faults.delete();
        run_mbist();

        check("T1 fail count == 0", mif.fail_count == 0);
        check("T1 fail flag == 0", mif.fail_flag == 0);
        check("T1 repair count == 0", mif.repair_count == 0);

        // -----------------------------------------------------
        // TEST 2: SINGLE FAULT AND REPAIR
        // Switch 3 is expected to map to LFSR address 8.
        // -----------------------------------------------------
        $display("\n--- TEST 2: SINGLE FAULT ---");

        full_repair_reset();
        cur_faults = {3};
        run_mbist();

        check("T2 fault detected", mif.fail_count == 1);
        check("T2 fail flag asserted", mif.fail_flag == 1);
        check("T2 one repair allocated", mif.repair_count == 1);
        check("T2 one repair event", observed_repairs == 1);

        check_repair_pair(0, 10'd8, 10'd256, "T2");

        // -----------------------------------------------------
        // TEST 3: POST-REPAIR RETEST
        // -----------------------------------------------------
        $display("\n--- TEST 3: POST-REPAIR RETEST ---");

        run_mbist();

        check("T3 fail count == 0", mif.fail_count == 0);
        check("T3 repair retained", mif.repair_count == 1);

        // -----------------------------------------------------
        // TEST 4: MULTIPLE FAULTS
        // -----------------------------------------------------
        $display("\n--- TEST 4: MULTIPLE FAULTS ---");

        full_repair_reset();
        cur_faults = {7, 0, 4, 2};
        run_mbist();

        check("T4 four faults detected", mif.fail_count == 4);
        check("T4 four repairs allocated", mif.repair_count == 4);
        check("T4 four repair events", observed_repairs == 4);

        // -----------------------------------------------------
        // TEST 5: REPAIR RESET
        // -----------------------------------------------------
        $display("\n--- TEST 5: REPAIR RESET ---");

        full_repair_reset();

        check("T5 repair count cleared", mif.repair_count == 0);
        check("T5 repair full cleared", mif.repair_full == 0);

        cur_faults = {5};
        run_mbist();

        check("T5 fault detected after reset", mif.fail_count == 1);
        check("T5 repair allocated", mif.repair_count == 1);

        // -----------------------------------------------------
        // TEST 6: RANDOMIZED REGRESSION
        // -----------------------------------------------------
        $display("\n--- TEST 6: RANDOMIZED REGRESSION ---");

        for (r = 1; r <= NUM_RANDOM_TESTS; r = r + 1)
            randomized_test(r);

        // -----------------------------------------------------
        // SUMMARY
        // -----------------------------------------------------
        $display("\n======================================");
        $display(" FINAL TEST SUMMARY");
        $display(" Passed checks = %0d", pass_cnt);
        $display(" Failed checks = %0d", fail_cnt);
        $display("======================================");

        if (fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED");

        $finish;
    end

    // =========================================================
    // GLOBAL WATCHDOG
    // =========================================================
    initial begin
        #5_000_000;
        $display("ERROR: GLOBAL TIMEOUT");
        $finish;
    end

endmodule
