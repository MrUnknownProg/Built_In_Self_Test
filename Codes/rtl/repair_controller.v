`timescale 1ns / 1ps

module repair_controller #(
    parameter ADDR_WIDTH  = 10,
    parameter DEPTH       = 1024,
    parameter SPARE_START = 256,
    parameter NUM_FAULTS  = 8
)(
    input wire clk_i,
    input wire rst_i,

    input wire repair_reset_i,

    input wire mbist_done_i,

    input wire [ADDR_WIDTH-1:0] fault_addr_i,
    input wire                  fault_valid_i,
    input wire [2:0]            fault_id_i,

    input wire [23:0] fault_order_i,
    input wire [3:0]  fault_order_count_i,

    input wire [ADDR_WIDTH-1:0] lookup_addr_i,

    output reg [ADDR_WIDTH-1:0] lookup_phys_addr_o,
    output reg                  lookup_valid_o,

    output reg [ADDR_WIDTH-1:0] repair_count_o,
    output reg                  repair_full_o,

    output reg [ADDR_WIDTH-1:0] repaired_logical_addr_o,
    output reg [ADDR_WIDTH-1:0] repaired_physical_addr_o,
    output reg                  repaired_valid_o
);

    // =========================================================
    // PARAMETERS
    // =========================================================

    localparam integer SPARE_COUNT = DEPTH - SPARE_START;


    // =========================================================
    // REPAIR TABLE
    //
    // repair_table[logical_address] = physical_address
    //
    // Example:
    //
    // repair_table[1] = 256
    //
    // means:
    //
    // logical address 1 -> physical address 256
    // =========================================================

    reg [ADDR_WIDTH-1:0]
        repair_table [0:DEPTH-1];

    reg
        repair_valid [0:DEPTH-1];


    // =========================================================
    // DETECTED FAULT ADDRESS
    //
    // Indexed by fault ID.
    //
    // Example:
    //
    // detected_addr[0] = address detected for fault 0
    // detected_addr[5] = address detected for fault 5
    // =========================================================

    reg [ADDR_WIDTH-1:0]
        detected_addr [0:NUM_FAULTS-1];

    reg [NUM_FAULTS-1:0]
        detected_valid;


    // =========================================================
    // ALLOCATION TRACKING
    //
    // Prevents one fault ID from being allocated repeatedly.
    // =========================================================

    reg [NUM_FAULTS-1:0]
        allocated_fault;


    // =========================================================
    // NEXT AVAILABLE SPARE ADDRESS
    //
    // Starts at 256.
    // =========================================================

    reg [ADDR_WIDTH-1:0]
        next_spare_addr;


    // =========================================================
    // ALLOCATION CONTROL
    // =========================================================

    reg [3:0]
        allocation_index;

    reg
        allocation_active;


    // =========================================================
    // MBIST DONE EDGE DETECTION
    //
    // Protects the repair controller from a sticky DONE signal.
    //
    // Allocation starts only when:
    //
    //     mbist_done_i = 1
    //     mbist_done_d = 0
    //
    // i.e. a rising edge.
    // =========================================================

    reg mbist_done_d;


    // =========================================================
    // CURRENT FAULT ID
    // =========================================================

    reg [2:0]
        current_fault_id;


    integer i;


    // =========================================================
    // FUNCTION:
    // GET FAULT ID FROM ACTIVATION ORDER
    //
    // fault_order_i contains eight 3-bit fault IDs:
    //
    // [2:0]    = order 0
    // [5:3]    = order 1
    // [8:6]    = order 2
    // [11:9]   = order 3
    // [14:12]  = order 4
    // [17:15]  = order 5
    // [20:18]  = order 6
    // [23:21]  = order 7
    // =========================================================

    function [2:0] get_fault_id;

        input [23:0] order_bus;
        input [3:0]  index;

        begin

            case (index)

                4'd0:
                    get_fault_id = order_bus[2:0];

                4'd1:
                    get_fault_id = order_bus[5:3];

                4'd2:
                    get_fault_id = order_bus[8:6];

                4'd3:
                    get_fault_id = order_bus[11:9];

                4'd4:
                    get_fault_id = order_bus[14:12];

                4'd5:
                    get_fault_id = order_bus[17:15];

                4'd6:
                    get_fault_id = order_bus[20:18];

                4'd7:
                    get_fault_id = order_bus[23:21];

                default:
                    get_fault_id = 3'd0;

            endcase

        end

    endfunction


    // =========================================================
    // MAIN SEQUENTIAL LOGIC
    // =========================================================

    always @(posedge clk_i) begin

        // =====================================================
        // NORMAL MBIST RESET
        //
        // IMPORTANT:
        //
        // This reset DOES NOT clear the repair table.
        //
        // Existing repair mappings must survive a normal
        // MBIST reset.
        // =====================================================

        if (rst_i) begin

            // -----------------------------------------------
            // Reset current MBIST detection information
            // -----------------------------------------------

            detected_valid <=
                {NUM_FAULTS{1'b0}};

            allocated_fault <=
                {NUM_FAULTS{1'b0}};

            allocation_index <=
                4'd0;

            allocation_active <=
                1'b0;

            mbist_done_d <=
                1'b0;

            repaired_valid_o <=
                1'b0;


            // -----------------------------------------------
            // Clear detected fault addresses
            // -----------------------------------------------

            for (i = 0; i < NUM_FAULTS; i = i + 1) begin

                detected_addr[i] <=
                    {ADDR_WIDTH{1'b0}};

            end


            // -----------------------------------------------
            // Persistent repair information is NOT modified.
            //
            // Do not put these inside normal reset:
            //
            // repair_table
            // repair_valid
            // repair_count_o
            // repair_full_o
            // next_spare_addr
            // -----------------------------------------------


            // -----------------------------------------------
            // If both resets are asserted during initial
            // startup, initialize the repair system.
            // -----------------------------------------------

            if (repair_reset_i) begin

                repair_count_o <=
                    {ADDR_WIDTH{1'b0}};

                repair_full_o <=
                    1'b0;

                next_spare_addr <=
                    SPARE_START;


                repaired_logical_addr_o <=
                    {ADDR_WIDTH{1'b0}};

                repaired_physical_addr_o <=
                    {ADDR_WIDTH{1'b0}};


                for (i = 0; i < DEPTH; i = i + 1) begin

                    repair_table[i] <=
                        {ADDR_WIDTH{1'b0}};

                    repair_valid[i] <=
                        1'b0;

                end

            end

        end


        // =====================================================
        // EXPLICIT REPAIR RESET
        //
        // This is the ONLY reset that normally clears the
        // repair table.
        // =====================================================

        else if (repair_reset_i) begin

            // -----------------------------------------------
            // Clear repair count
            // -----------------------------------------------

            repair_count_o <=
                {ADDR_WIDTH{1'b0}};


            // -----------------------------------------------
            // Clear full flag
            // -----------------------------------------------

            repair_full_o <=
                1'b0;


            // -----------------------------------------------
            // Restart spare allocation from address 256
            // -----------------------------------------------

            next_spare_addr <=
                SPARE_START;


            // -----------------------------------------------
            // Reset allocation controller
            // -----------------------------------------------

            allocation_index <=
                4'd0;

            allocation_active <=
                1'b0;


            // -----------------------------------------------
            // Reset done edge detector
            // -----------------------------------------------

            mbist_done_d <=
                1'b0;


            // -----------------------------------------------
            // Clear debug outputs
            // -----------------------------------------------

            repaired_logical_addr_o <=
                {ADDR_WIDTH{1'b0}};

            repaired_physical_addr_o <=
                {ADDR_WIDTH{1'b0}};

            repaired_valid_o <=
                1'b0;


            // -----------------------------------------------
            // Clear detected fault information
            // -----------------------------------------------

            detected_valid <=
                {NUM_FAULTS{1'b0}};

            allocated_fault <=
                {NUM_FAULTS{1'b0}};


            for (i = 0; i < NUM_FAULTS; i = i + 1) begin

                detected_addr[i] <=
                    {ADDR_WIDTH{1'b0}};

            end


            // -----------------------------------------------
            // Clear complete repair table
            // -----------------------------------------------

            for (i = 0; i < DEPTH; i = i + 1) begin

                repair_table[i] <=
                    {ADDR_WIDTH{1'b0}};

                repair_valid[i] <=
                    1'b0;

            end

        end


        // =====================================================
        // NORMAL OPERATION
        // =====================================================

        else begin

            // -----------------------------------------------
            // repaired_valid_o is a one-clock pulse.
            // -----------------------------------------------

            repaired_valid_o <=
                1'b0;


            // -----------------------------------------------
            // Store previous MBIST DONE state.
            // -----------------------------------------------

            mbist_done_d <=
                mbist_done_i;


            // =================================================
            // CAPTURE DETECTED FAULT
            // =================================================

            if (fault_valid_i) begin

                if (fault_id_i < NUM_FAULTS) begin

                    /*
                     * Store the address according to fault ID.
                     *
                     * Example:
                     *
                     * fault_id = 5
                     * fault_addr = 35
                     *
                     * becomes:
                     *
                     * detected_addr[5] = 35
                     */

                    detected_addr[fault_id_i] <=
                        fault_addr_i;

                    detected_valid[fault_id_i] <=
                        1'b1;

                end

            end


            // =================================================
            // START ALLOCATION
            //
            // Allocation starts only once per MBIST run.
            // =================================================

            if (mbist_done_i &&
                !mbist_done_d &&
                !allocation_active &&
                (fault_order_count_i != 4'd0)) begin

                allocation_index <=
                    4'd0;

                allocation_active <=
                    1'b1;

            end


            // =================================================
            // ALLOCATION PROCESS
            // =================================================

            if (allocation_active) begin

                // ---------------------------------------------
                // Get fault ID according to activation order.
                // ---------------------------------------------

                current_fault_id =
                    get_fault_id(
                        fault_order_i,
                        allocation_index
                    );


                // ---------------------------------------------
                // Check whether this fault was detected.
                // ---------------------------------------------

                if (detected_valid[current_fault_id]) begin


                    // =================================================
                    // CHECK WHETHER THIS LOGICAL ADDRESS ALREADY
                    // HAS A REPAIR.
                    //
                    // This prevents:
                    //
                    //     Logical 1 -> Physical 256
                    //     Logical 1 -> Physical 257
                    //
                    // =================================================

                    if (!repair_valid[
                            detected_addr[current_fault_id]
                        ]) begin


                        // =============================================
                        // CHECK SPARE MEMORY CAPACITY
                        // =============================================

                        if (repair_count_o < SPARE_COUNT) begin


                            // -----------------------------------------
                            // CREATE LOGICAL -> PHYSICAL MAPPING
                            // -----------------------------------------

                            repair_table[
                                detected_addr[current_fault_id]
                            ] <=
                                next_spare_addr;

                            repair_valid[
                                detected_addr[current_fault_id]
                            ] <=
                                1'b1;


                            // -----------------------------------------
                            // DEBUG OUTPUT
                            // -----------------------------------------

                            repaired_logical_addr_o <=
                                detected_addr[current_fault_id];

                            repaired_physical_addr_o <=
                                next_spare_addr;

                            repaired_valid_o <=
                                1'b1;


                            // -----------------------------------------
                            // INCREMENT REPAIR COUNT
                            // -----------------------------------------

                            repair_count_o <=
                                repair_count_o + 10'd1;


                            // -----------------------------------------
                            // ALLOCATE NEXT SPARE ADDRESS
                            // -----------------------------------------

                            if (next_spare_addr ==
                                DEPTH - 1) begin

                                repair_full_o <=
                                    1'b1;

                            end

                            else begin

                                next_spare_addr <=
                                    next_spare_addr + 1'b1;

                            end

                        end

                        else begin

                            // -----------------------------------------
                            // No spare locations remaining.
                            // -----------------------------------------

                            repair_full_o <=
                                1'b1;

                        end

                    end


                    // ---------------------------------------------
                    // Mark this fault ID as processed.
                    //
                    // Even if the logical address was already
                    // repaired, it must not be processed again.
                    // ---------------------------------------------

                    allocated_fault[current_fault_id] <=
                        1'b1;

                end


                // =================================================
                // MOVE TO NEXT ACTIVATION-ORDER ENTRY
                // =================================================

                if ((allocation_index + 1'b1) >=
                    fault_order_count_i) begin

                    allocation_active <=
                        1'b0;

                end

                else begin

                    allocation_index <=
                        allocation_index + 1'b1;

                end

            end

        end

    end


    // =========================================================
    // REPAIR LOOKUP
    //
    // Current architecture keeps this lookup combinational.
    //
    // logical address
    //       |
    //       v
    // repair_valid[]
    //       |
    //       +---- 0 ----> original address
    //       |
    //       +---- 1 ----> repair_table[]
    // =========================================================

    always @(*) begin

        if ((lookup_addr_i < DEPTH) &&
            repair_valid[lookup_addr_i]) begin

            lookup_valid_o <=
                1'b1;

            lookup_phys_addr_o <=
                repair_table[lookup_addr_i];

        end

        else begin

            lookup_valid_o <=
                1'b0;

            lookup_phys_addr_o <=
                lookup_addr_i;

        end

    end

endmodule