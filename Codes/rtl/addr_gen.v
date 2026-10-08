`timescale 1ns / 1ps

module addr_gen #(
    parameter ADDR_WIDTH = 10,
    parameter LAST_ADDR  = 10'd255
)(
    input wire clk_i,
    input wire rst_i,
    input wire addr_en_i,
    input wire addr_rst_i,
    input wire addr_dir_i,

    output reg [ADDR_WIDTH-1:0] addr_o,

    output wire addr_done_o
);
    
    reg [ADDR_WIDTH-1:0] addr_o;

    localparam [ADDR_WIDTH-1:0] MIN_ADDR = {ADDR_WIDTH{1'b0}};

    localparam [ADDR_WIDTH-1:0] MAX_ADDR = LAST_ADDR;

    always @(posedge clk_i) begin

        if (rst_i) begin

            addr_o <= MIN_ADDR;

        end

        else if (addr_rst_i) begin

            if (addr_dir_i)
                addr_o <= MIN_ADDR;
            else
                addr_o <= MAX_ADDR;

        end

        else if (addr_en_i) begin

            if (addr_dir_i) begin

                if (addr_o < MAX_ADDR)
                    addr_o <= addr_o + 10'd1;

            end

            else begin

                if (addr_o > MIN_ADDR)
                    addr_o <= addr_o - 10'd1;

            end

        end

    end

    assign addr_done_o = addr_dir_i ? (addr_o == MAX_ADDR) : (addr_o == MIN_ADDR);

endmodule