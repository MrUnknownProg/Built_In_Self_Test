`timescale 1ns / 1ps

module control_logic #(
    parameter ADDR_WIDTH = 10
)(
    input  wire        clk_i,
    input  wire        rst_i,
    input  wire        start_i,

    input  wire        addr_done_i,

    // LFSR fault-address generation
    input  wire        fault_addr_valid_i,

    output reg         addr_en_o,
    output reg         addr_rst_o,

    output reg         we_o,
    output reg         compare_en_o,

    output reg         done_o,

    output reg         fault_generate_o,

    output reg [1:0]   pattern_sel_o,

    output reg         addr_dir_o
);

    // =========================================================
    // FSM STATES
    // =========================================================

    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] GEN_START    = 4'd1;
    localparam [3:0] GEN_WAIT     = 4'd2;
    localparam [3:0] INIT         = 4'd3;
    localparam [3:0] WRITE        = 4'd4;
    localparam [3:0] READ_SETUP   = 4'd5;
    localparam [3:0] READ_WAIT    = 4'd6;
    localparam [3:0] READ_COMPARE = 4'd7;
    localparam [3:0] READ_ADVANCE = 4'd8;
    localparam [3:0] DONE         = 4'd9;

    reg [3:0] state;
    reg [3:0] next_state;

    // =========================================================
    // STATE REGISTER
    // =========================================================

    always @(posedge clk_i) begin

        if (rst_i)
            state <= IDLE;
        else
            state <= next_state;

    end

    // =========================================================
    // NEXT STATE LOGIC
    // =========================================================

    always @(*) begin

        next_state = state;

        case (state)

            // -------------------------------------------------
            // IDLE
            // -------------------------------------------------

            IDLE: begin

                if (start_i)
                    next_state = GEN_START;

            end

            // -------------------------------------------------
            // Start LFSR fault-address generation
            // -------------------------------------------------

            GEN_START: begin

                next_state = GEN_WAIT;

            end

            // -------------------------------------------------
            // Wait until all 8 LFSR addresses are generated
            // -------------------------------------------------

            GEN_WAIT: begin

                if (fault_addr_valid_i)
                    next_state = INIT;

            end

            // -------------------------------------------------
            // Initialize memory address
            // -------------------------------------------------

            INIT: begin

                next_state = WRITE;

            end

            // -------------------------------------------------
            // Write 0 to all normal memory addresses
            // 0 -> 255
            // -------------------------------------------------

            WRITE: begin

                if (addr_done_i)
                    next_state = READ_SETUP;

            end

            // -------------------------------------------------
            // Reset address to 0 before read
            // -------------------------------------------------

            READ_SETUP: begin

                next_state = READ_WAIT;

            end

            // -------------------------------------------------
            // Wait one clock for synchronous BRAM read
            // -------------------------------------------------

            READ_WAIT: begin

                next_state = READ_COMPARE;

            end

            // -------------------------------------------------
            // Compare current BRAM output
            //
            // IMPORTANT:
            // Address is NOT incremented here.
            // This keeps addr_i aligned with doutb.
            // -------------------------------------------------

            READ_COMPARE: begin

                if (addr_done_i)
                    next_state = DONE;
                else
                    next_state = READ_ADVANCE;

            end

            // -------------------------------------------------
            // Advance to next address
            // -------------------------------------------------

            READ_ADVANCE: begin

                next_state = READ_WAIT;

            end

            // -------------------------------------------------
            // MBIST complete
            //
            // A new start is accepted without reset.
            // -------------------------------------------------

            DONE: begin

                if (start_i)
                    next_state = GEN_START;

            end

            default: begin

                next_state = IDLE;

            end

        endcase

    end

    // =========================================================
    // OUTPUT LOGIC
    // =========================================================

    always @(*) begin

        // Defaults
        addr_en_o        = 1'b0;
        addr_rst_o       = 1'b0;
        we_o             = 1'b0;
        compare_en_o     = 1'b0;
        done_o           = 1'b0;
        fault_generate_o = 1'b0;
        pattern_sel_o    = 2'b00;

        // UP direction
        addr_dir_o       = 1'b1;

        case (state)

            // -------------------------------------------------
            // Start LFSR
            // -------------------------------------------------

            GEN_START: begin

                fault_generate_o = 1'b1;

            end

            // -------------------------------------------------
            // Initialize address generator to 0
            // -------------------------------------------------

            INIT: begin

                addr_rst_o = 1'b1;

            end

            // -------------------------------------------------
            // Write zeros
            // -------------------------------------------------

            WRITE: begin

                addr_en_o     = 1'b1;
                we_o          = 1'b1;
                pattern_sel_o = 2'b00;
                addr_dir_o    = 1'b1;

            end

            // -------------------------------------------------
            // Reset address before read
            // -------------------------------------------------

            READ_SETUP: begin

                addr_rst_o = 1'b1;

            end

            // -------------------------------------------------
            // BRAM latency
            // -------------------------------------------------

            READ_WAIT: begin

                addr_en_o     = 1'b0;
                compare_en_o  = 1'b0;
                pattern_sel_o = 2'b00;
                addr_dir_o    = 1'b1;

            end

            // -------------------------------------------------
            // Compare current address/data
            // -------------------------------------------------

            READ_COMPARE: begin

                addr_en_o     = 1'b0;
                compare_en_o  = 1'b1;
                pattern_sel_o = 2'b00;
                addr_dir_o    = 1'b1;

            end

            // -------------------------------------------------
            // Increment address after comparison
            // -------------------------------------------------

            READ_ADVANCE: begin

                addr_en_o     = 1'b1;
                compare_en_o  = 1'b0;
                pattern_sel_o = 2'b00;
                addr_dir_o    = 1'b1;

            end

            // -------------------------------------------------
            // DONE
            // -------------------------------------------------

            DONE: begin

                done_o = 1'b1;

            end

            default: begin

            end

        endcase

    end

endmodule
