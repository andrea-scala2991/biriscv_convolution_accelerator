`timescale 1ns / 1ps

module BRAM #(
    parameter integer WORD_SIZE = 32,     // bits per element
    parameter integer RAM_DEPTH = 256     // number of elements
)(
    input  logic clk,

    // -------- Port A --------
    input  logic [$clog2(RAM_DEPTH)-1:0] addr_a,
    input  logic [WORD_SIZE-1:0]         din_a,
    output logic [WORD_SIZE-1:0]         dout_a,
    input  logic                         we_a,
    input  logic                         en_a,

    // -------- Port B --------
    input  logic [$clog2(RAM_DEPTH)-1:0] addr_b,
    input  logic [WORD_SIZE-1:0]         din_b,
    output logic [WORD_SIZE-1:0]         dout_b,
    input  logic                         we_b,
    input  logic                         en_b
);

    // ------------------------------------------------------------------------
    // Memory declaration - BRAM inference
    // ------------------------------------------------------------------------
    (* ram_style = "block" *)
    logic [WORD_SIZE-1:0] mem [0:RAM_DEPTH-1];

    // ------------------------------------------------------------------------
    // Port A
    // ------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (en_a) begin
            if (we_a)
                mem[addr_a] <= din_a;

            dout_a <= mem[addr_a];
        end
    end

    // ------------------------------------------------------------------------
    // Port B
    // ------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (en_b) begin
            if (we_b)
                mem[addr_b] <= din_b;

            dout_b <= mem[addr_b];
        end
    end

endmodule
