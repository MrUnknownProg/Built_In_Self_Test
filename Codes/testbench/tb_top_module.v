`timescale 1ns / 1ps

module tb_top_mbist;

    localparam integer ADDR_WIDTH  = 10;
    localparam integer NUM_FAULTS  = 8;
    localparam integer SPARE_START = 256;

    // 100 MHz clock:
    // Period = 10 ns
    // Half period = 5 ns
    localparam integer MBIST_TIMEOUT_CYCLES = 3000;

    // =========================================================
    // DUT INPUTS
    // =========================================================

    reg         clk_i_0;
    reg         rst_i_0;
    reg         start_i_0;
    reg [7:0]   fault_switch_i_0;
    reg         repair_reset_i_0;

    // =========================================================
    // DUT OUTPUTS
    // =========================================================

    wire        done_o_0;
    wire [7:0]  fail_count_o_0;
    wire        fail_flag_o_0;

    wire [9:0]  fault_addr_o;
    wire        fault_addr_valid_o;

    wire        fault_hit_o_0;

    wire [9:0]  repair_count_o_0;
    wire        repair_full_o_0;

    wire [9:0]  repaired_logical_addr_o_0;
    wire [9:0]  repaired_physical_addr_o_0;

    wire        repaired_valid_o_0;
    wire        valid_o_0;

    // =========================================================
    // DUT
    // =========================================================

    top_mbist dut
    (
        .clk_i_0                    (clk_i_0),
        .rst_i_0                    (rst_i_0),
        .start_i_0                  (start_i_0),

        .fault_switch_i_0           (fault_switch_i_0),

        .repair_reset_i_0           (repair_reset_i_0),

        .done_o_0                   (done_o_0),

        .fail_count_o_0             (fail_count_o_0),
        .fail_flag_o_0              (fail_flag_o_0),

        .fault_addr_o               (fault_addr_o),
        .fault_addr_valid_o         (fault_addr_valid_o),

        .fault_hit_o_0              (fault_hit_o_0),

        .repair_count_o_0           (repair_count_o_0),
        .repair_full_o_0            (repair_full_o_0),

        .repaired_logical_addr_o_0  (repaired_logical_addr_o_0),
        .repaired_physical_addr_o_0 (repaired_physical_addr_o_0),

        .repaired_valid_o_0         (repaired_valid_o_0),

        .valid_o_0                  (valid_o_0)
    );

    // =========================================================
    // 100 MHz CLOCK
    // =========================================================

    initial begin
        clk_i_0 = 1'b0;

        forever
            #5 clk_i_0 = ~clk_i_0;
    end

    // =========================================================
    // TEST VARIABLES
    // =========================================================

    integer tests_passed;
    integer tests_failed;

    integer baseline_fail_count;
    integer single_fault_count;
    integer multiple_fault_count;
    integer all_fault_count;
    integer post_repair_count;

    integer observed_repairs;

    reg [9:0] observed_logical  [0:7];
    reg [9:0] observed_physical [0:7];

    // =========================================================
    // CAPTURE REPAIR EVENTS
    // =========================================================

    always @(posedge clk_i_0) begin

        if (repaired_valid_o_0 === 1'b1) begin

            if (observed_repairs < NUM_FAULTS) begin

                observed_logical[observed_repairs] =
                    repaired_logical_addr_o_0;

                observed_physical[observed_repairs] =
                    repaired_physical_addr_o_0;

                observed_repairs =
                    observed_repairs + 1;

            end

        end

    end

    // =========================================================
    // CLEAR OBSERVED REPAIRS
    // =========================================================

    task clear_observed_repairs;

        integer i;

        begin

            observed_repairs = 0;

            for (i = 0; i < NUM_FAULTS; i = i + 1) begin

                observed_logical[i]  = 10'd0;
                observed_physical[i] = 10'd0;

            end

        end

    endtask

    // =========================================================
    // CLEAR ALL FAULT SWITCHES
    // =========================================================
    // IMPORTANT:
    // fault_order_capture detects 0 -> 1 transitions.
    //
    // Switches are changed on the NEGEDGE so that the DUT
    // samples stable values on the following POSEDGE.
    // =========================================================

    task clear_fault_switches;

        begin

            @(negedge clk_i_0);

            fault_switch_i_0 = 8'b00000000;

            repeat (2)
                @(posedge clk_i_0);

        end

    endtask

    // =========================================================
    // MBIST RESET
    // =========================================================
    // Normal MBIST reset must not clear the repair table.
    // =========================================================

    task mbist_reset;

        begin

            rst_i_0 = 1'b1;

            repeat (3)
                @(posedge clk_i_0);

            rst_i_0 = 1'b0;

            repeat (2)
                @(posedge clk_i_0);

        end

    endtask

    // =========================================================
    // REPAIR RESET
    // =========================================================
    // Explicitly clears the repair table and spare allocation.
    // =========================================================

    task repair_reset;

        begin

            repair_reset_i_0 = 1'b1;

            repeat (3)
                @(posedge clk_i_0);

            repair_reset_i_0 = 1'b0;

            repeat (2)
                @(posedge clk_i_0);

        end

    endtask

    // =========================================================
    // START MBIST
    // =========================================================

    task start_mbist;

        begin

            start_i_0 = 1'b0;

            @(negedge clk_i_0);

            start_i_0 = 1'b1;

            @(negedge clk_i_0);

            start_i_0 = 1'b0;

        end

    endtask

    // =========================================================
    // WAIT FOR MBIST WITH TIMEOUT
    // =========================================================

    task wait_for_mbist;

        integer cycle_count;
        reg completed;

        begin

            cycle_count = 0;
            completed   = 1'b0;

            while (
                cycle_count < MBIST_TIMEOUT_CYCLES
            ) begin

                @(posedge clk_i_0);

                if (done_o_0 === 1'b1) begin

                    completed = 1'b1;
                    cycle_count = MBIST_TIMEOUT_CYCLES;

                end
                else begin

                    cycle_count = cycle_count + 1;

                end

            end

            if (!completed) begin

                $display("");
                $display("ERROR: MBIST TIMEOUT");
                $display(
                    "DONE never asserted within %0d cycles.",
                    MBIST_TIMEOUT_CYCLES
                );

                tests_failed = tests_failed + 1;

                $finish;

            end

            // =================================================
            // Allow repair controller to finish all allocations.
            //
            // Allocation starts after MBIST DONE and can generate
            // one repaired_valid event per fault.
            // =================================================

            repeat (NUM_FAULTS + 2)
                @(posedge clk_i_0);

        end

    endtask

    // =========================================================
    // PRINT REPAIR MAPPINGS
    // =========================================================

    task print_repairs;

        integer i;

        begin

            if (observed_repairs == 0) begin

                $display("No repair mappings allocated.");

            end
            else begin

                for (i = 0; i < observed_repairs; i = i + 1) begin

                    $display(
                        "Repair %0d : Logical %0d -> Physical %0d",
                        i + 1,
                        observed_logical[i],
                        observed_physical[i]
                    );

                end

            end

        end

    endtask

    // =========================================================
    // PRINT FAULT ORDER
    // =========================================================

    task print_fault_order;

        integer j;

        begin

            $display("");
            $display("---------- FAULT ORDER DEBUG ----------");

            $display(
                "Active faults = %b",
                dut.design_2_i.fault_order_capture_0_active_faults_o
            );

            $display(
                "Order count   = %0d",
                dut.design_2_i.fault_order_capture_0_fault_order_count_o
            );

            $display(
                "Order bus     = %024b",
                dut.design_2_i.fault_order_capture_0_fault_order_o
            );

            for (j = 0; j < 8; j = j + 1) begin

                case (j)

                    0:
                        $display(
                            "Order[%0d] = Fault %0d",
                            j,
                            dut.design_2_i.fault_order_capture_0_fault_order_o[2:0]
                        );

                    1:
                        $display(
                            "Order[%0d] = Fault %0d",
                            j,
                            dut.design_2_i.fault_order_capture_0_fault_order_o[5:3]
                        );

                    2:
                        $display(
                            "Order[%0d] = Fault %0d",
                            j,
                            dut.design_2_i.fault_order_capture_0_fault_order_o[8:6]
                        );

                    3:
                        $display(
                            "Order[%0d] = Fault %0d",
                            j,
                            dut.design_2_i.fault_order_capture_0_fault_order_o[11:9]
                        );

                    4:
                        $display(
                            "Order[%0d] = Fault %0d",
                            j,
                            dut.design_2_i.fault_order_capture_0_fault_order_o[14:12]
                        );

                    5:
                        $display(
                            "Order[%0d] = Fault %0d",
                            j,
                            dut.design_2_i.fault_order_capture_0_fault_order_o[17:15]
                        );

                    6:
                        $display(
                            "Order[%0d] = Fault %0d",
                            j,
                            dut.design_2_i.fault_order_capture_0_fault_order_o[20:18]
                        );

                    7:
                        $display(
                            "Order[%0d] = Fault %0d",
                            j,
                            dut.design_2_i.fault_order_capture_0_fault_order_o[23:21]
                        );

                endcase

            end

            $display("----------------------------------------");

        end

    endtask

    // =========================================================
    // MAIN TEST
    // =========================================================

    initial begin

        // =====================================================
        // INITIAL STATE
        // =====================================================

        rst_i_0           = 1'b0;
        start_i_0         = 1'b0;
        fault_switch_i_0  = 8'b00000000;
        repair_reset_i_0  = 1'b0;

        tests_passed = 0;
        tests_failed = 0;

        baseline_fail_count   = 0;
        single_fault_count    = 0;
        multiple_fault_count  = 0;
        all_fault_count       = 0;
        post_repair_count     = 0;

        clear_observed_repairs;

        // =====================================================
        // TEST 1
        // FULL RESET
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 1 : FULL RESET");
        $display("============================================");

        clear_fault_switches;
        repair_reset;
        mbist_reset;

        if (
            repair_count_o_0 === 10'd0 &&
            repair_full_o_0  === 1'b0
        ) begin

            $display(
                "Repair count = %0d",
                repair_count_o_0
            );

            $display(
                "Repair full  = %0d",
                repair_full_o_0
            );

            $display("TEST 1 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 1 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 2
        // FAULT OFF - BASELINE
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 2 : FAULT OFF - BASELINE");
        $display("============================================");

        clear_fault_switches;

        start_mbist;
        wait_for_mbist;

        baseline_fail_count = fail_count_o_0;

        $display(
            "FAIL COUNT = %0d",
            fail_count_o_0
        );

        if (
            fail_count_o_0 == 0 &&
            repair_count_o_0 == 0
        ) begin

            $display("TEST 2 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 2 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 3
        // LFSR FAULT ADDRESSES
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 3 : LFSR FAULT ADDRESSES");
        $display("============================================");

        $display(
            "Expected LFSR addresses = 1, 2, 4, 8, 17, 35, 71, 142"
        );

        #1;

        $display(
            "LFSR valid = %b",
            valid_o_0
        );

        $display("TEST 3 = PASS");

        tests_passed = tests_passed + 1;

        // =====================================================
        // TEST 4
        // FAULT 0 ONLY
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 4 : FAULT 0 ONLY");
        $display("============================================");

        repair_reset;
        mbist_reset;
        clear_observed_repairs;
        clear_fault_switches;

        @(negedge clk_i_0);
        fault_switch_i_0[0] = 1'b1;

        repeat (2)
            @(posedge clk_i_0);

        start_mbist;
        wait_for_mbist;

        single_fault_count = fail_count_o_0;

        $display(
            "FAIL COUNT = %0d",
            fail_count_o_0
        );

        $display(
            "REPAIR COUNT = %0d",
            repair_count_o_0
        );

        print_repairs;

        if (
            fail_count_o_0 == 1 &&
            repair_count_o_0 == 1 &&
            observed_repairs == 1
        ) begin

            $display("TEST 4 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 4 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 5
        // REPAIR ALLOCATION
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 5 : REPAIR ALLOCATION");
        $display("============================================");

        print_repairs;

        if (
            observed_repairs == 1 &&
            observed_logical[0] == 10'd1 &&
            observed_physical[0] == 10'd256
        ) begin

            $display("Repair allocated to spare 256.");
            $display("TEST 5 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 5 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 6
        // REPAIR RETENTION
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 6 : REPAIR RETENTION");
        $display("============================================");

        mbist_reset;

        $display(
            "Repair count after MBIST reset = %0d",
            repair_count_o_0
        );

        if (
            repair_count_o_0 == 1
        ) begin

            $display("TEST 6 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 6 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 7
        // POST-REPAIR MBIST
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 7 : POST-REPAIR MBIST");
        $display("============================================");

        clear_fault_switches;

        @(negedge clk_i_0);
        fault_switch_i_0[0] = 1'b1;

        repeat (2)
            @(posedge clk_i_0);

        start_mbist;
        wait_for_mbist;

        post_repair_count = fail_count_o_0;

        $display(
            "FAIL COUNT = %0d",
            fail_count_o_0
        );

        if (
            fail_count_o_0 == baseline_fail_count
        ) begin

            $display("TEST 7 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 7 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 8
        // FINAL REMAPPING VERIFICATION
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 8 : FINAL REMAPPING VERIFICATION");
        $display("============================================");

        $display(
            "Baseline      = %0d",
            baseline_fail_count
        );

        $display(
            "Before repair = %0d",
            single_fault_count
        );

        $display(
            "After repair  = %0d",
            post_repair_count
        );

        print_repairs;

        if (
            baseline_fail_count == 0 &&
            single_fault_count == 1 &&
            post_repair_count == 0
        ) begin

            $display("TEST 8 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 8 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 9
        // FAULT 1 ONLY
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 9 : FAULT 1 ONLY");
        $display("============================================");

        clear_fault_switches;
        repair_reset;
        mbist_reset;
        clear_observed_repairs;
    

        @(negedge clk_i_0);
        fault_switch_i_0[1] = 1'b1;

        repeat (2)
            @(posedge clk_i_0);

        print_fault_order;

        start_mbist;
        wait_for_mbist;

        $display(
            "FAIL COUNT = %0d",
            fail_count_o_0
        );

        print_repairs;

        if (
            fail_count_o_0 == 1 &&
            repair_count_o_0 == 1 &&
            observed_repairs == 1 &&
            observed_logical[0] == 10'd2 &&
            observed_physical[0] == 10'd256
        ) begin

            $display("TEST 9 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 9 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 10
        // MULTIPLE ACTIVE FAULTS
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 10 : MULTIPLE ACTIVE FAULTS");
        $display("============================================");

        clear_fault_switches;
        repair_reset;
        mbist_reset;
        clear_observed_repairs;


        @(negedge clk_i_0);
        fault_switch_i_0[0] = 1'b1;
        repeat (3) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[1] = 1'b1;
        repeat (3) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[2] = 1'b1;
        repeat (3) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[3] = 1'b1;
        repeat (3) @(posedge clk_i_0);

        print_fault_order;

        start_mbist;
        wait_for_mbist;

        multiple_fault_count = fail_count_o_0;

        $display(
            "FAIL COUNT = %0d",
            fail_count_o_0
        );

        $display(
            "REPAIR COUNT = %0d",
            repair_count_o_0
        );

        print_repairs;

        if (
            fail_count_o_0 == 4 &&
            repair_count_o_0 == 4 &&
            observed_repairs == 4 &&
            observed_logical[0] == 10'd1 &&
            observed_logical[1] == 10'd2 &&
            observed_logical[2] == 10'd4 &&
            observed_logical[3] == 10'd8 &&
            observed_physical[0] == 10'd256 &&
            observed_physical[1] == 10'd257 &&
            observed_physical[2] == 10'd258 &&
            observed_physical[3] == 10'd259
        ) begin

            $display("TEST 10 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 10 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 11
        // ALL EIGHT FAULTS
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 11 : ALL EIGHT FAULTS");
        $display("============================================");

        clear_fault_switches;
        repair_reset;
        mbist_reset;
        clear_observed_repairs;

        @(negedge clk_i_0);
        fault_switch_i_0[0] = 1'b1;
        repeat (2) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[1] = 1'b1;
        repeat (2) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[2] = 1'b1;
        repeat (2) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[3] = 1'b1;
        repeat (2) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[4] = 1'b1;
        repeat (2) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[5] = 1'b1;
        repeat (2) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[6] = 1'b1;
        repeat (2) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[7] = 1'b1;
        repeat (2) @(posedge clk_i_0);

        print_fault_order;

        start_mbist;
        wait_for_mbist;

        all_fault_count = fail_count_o_0;

        $display(
            "FAIL COUNT = %0d",
            fail_count_o_0
        );

        $display(
            "REPAIR COUNT = %0d",
            repair_count_o_0
        );

        print_repairs;

        if (
            fail_count_o_0 == 8 &&
            repair_count_o_0 == 8 &&
            observed_repairs == 8 &&
            observed_logical[0] == 10'd1 &&
            observed_logical[1] == 10'd2 &&
            observed_logical[2] == 10'd4 &&
            observed_logical[3] == 10'd8 &&
            observed_logical[4] == 10'd17 &&
            observed_logical[5] == 10'd35 &&
            observed_logical[6] == 10'd71 &&
            observed_logical[7] == 10'd142 &&
            observed_physical[0] == 10'd256 &&
            observed_physical[1] == 10'd257 &&
            observed_physical[2] == 10'd258 &&
            observed_physical[3] == 10'd259 &&
            observed_physical[4] == 10'd260 &&
            observed_physical[5] == 10'd261 &&
            observed_physical[6] == 10'd262 &&
            observed_physical[7] == 10'd263
        ) begin

            $display("TEST 11 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 11 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 12
        // NONSEQUENTIAL SWITCH ACTIVATION
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 12 : NONSEQUENTIAL FAULT ORDER");
        $display("============================================");

        clear_fault_switches;
        repair_reset;
        mbist_reset;
        clear_observed_repairs;


        @(negedge clk_i_0);
        fault_switch_i_0[5] = 1'b1;
        $display("Activated SW5");
        repeat (3) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[2] = 1'b1;
        $display("Activated SW2");
        repeat (3) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[7] = 1'b1;
        $display("Activated SW7");
        repeat (3) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[3] = 1'b1;
        $display("Activated SW3");
        repeat (3) @(posedge clk_i_0);

        @(negedge clk_i_0);
        fault_switch_i_0[1] = 1'b1;
        $display("Activated SW1");
        repeat (3) @(posedge clk_i_0);

        $display(
            "Expected activation order = 5 -> 2 -> 7 -> 3 -> 1"
        );

        print_fault_order;

        start_mbist;
        wait_for_mbist;

        $display(
            "FAIL COUNT = %0d",
            fail_count_o_0
        );

        $display(
            "REPAIR COUNT = %0d",
            repair_count_o_0
        );

        print_repairs;

        if (
            fail_count_o_0 == 5 &&
            repair_count_o_0 == 5 &&
            observed_repairs == 5 &&
            observed_logical[0] == 10'd35 &&
            observed_logical[1] == 10'd4 &&
            observed_logical[2] == 10'd142 &&
            observed_logical[3] == 10'd8 &&
            observed_logical[4] == 10'd2 &&
            observed_physical[0] == 10'd256 &&
            observed_physical[1] == 10'd257 &&
            observed_physical[2] == 10'd258 &&
            observed_physical[3] == 10'd259 &&
            observed_physical[4] == 10'd260
        ) begin

            $display("TEST 12 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 12 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // TEST 13
        // UNIQUE SPARE ALLOCATION
        // =====================================================

        $display("");
        $display("============================================");
        $display(" TEST 13 : UNIQUE SPARE ALLOCATION");
        $display("============================================");

        if (
            observed_repairs == 5 &&
            observed_logical[0]  == 10'd35 &&
            observed_logical[1]  == 10'd4 &&
            observed_logical[2]  == 10'd142 &&
            observed_logical[3]  == 10'd8 &&
            observed_logical[4]  == 10'd2 &&
            observed_physical[0] == 10'd256 &&
            observed_physical[1] == 10'd257 &&
            observed_physical[2] == 10'd258 &&
            observed_physical[3] == 10'd259 &&
            observed_physical[4] == 10'd260
        ) begin

            $display(
                "Spare allocation = 256, 257, 258, 259, 260"
            );

            $display("TEST 13 = PASS");

            tests_passed = tests_passed + 1;

        end
        else begin

            $display("TEST 13 = FAIL");

            tests_failed = tests_failed + 1;

        end

        // =====================================================
        // FINAL SUMMARY
        // =====================================================

        $display("");
        $display("================================================");
        $display("                 FINAL SUMMARY");
        $display("================================================");

        $display(
            "Baseline fail count       = %0d",
            baseline_fail_count
        );

        $display(
            "Single fault count        = %0d",
            single_fault_count
        );

        $display(
            "Multiple fault count      = %0d",
            multiple_fault_count
        );

        $display(
            "All fault count           = %0d",
            all_fault_count
        );

        $display(
            "Post-repair count         = %0d",
            post_repair_count
        );

        $display("");

        $display(
            "Tests passed              = %0d",
            tests_passed
        );

        $display(
            "Tests failed              = %0d",
            tests_failed
        );

        $display("================================================");

        if (tests_failed == 0)
            $display("             ALL TESTS PASSED");
        else
            $display("             TESTS FAILED");

        $display("================================================");

        #100;

        $finish;

    end

endmodule