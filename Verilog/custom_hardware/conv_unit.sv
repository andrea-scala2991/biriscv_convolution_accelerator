`timescale 1ns / 1ps

module conv_unit(
     input  logic         clk_i
    ,input  logic         rst_i

    // Issued opcode bundle (slot0)
    ,input  logic         opcode_valid_i
    ,input  logic [31:0]  opcode_opcode_i
    ,input  logic [31:0]  opcode_pc_i
    ,input  logic         opcode_invalid_i
    ,input  logic [4:0]   opcode_rd_idx_i
    ,input  logic [4:0]   opcode_ra_idx_i
    ,input  logic [4:0]   opcode_rb_idx_i
    ,input  logic [31:0]  opcode_ra_operand_i
    ,input  logic [31:0]  opcode_rb_operand_i

    // Unit status / completion
    ,output logic         busy_o
    ,output logic         valid_o
    ,output logic [31:0]  writeback_o
);

    // ---------------------------
    // Custom instruction encoding
    // ---------------------------
    localparam logic [6:0] OPC_CUSTOM0 = 7'b0001011;

    localparam logic [2:0] F3_CLR = 3'b000;
    localparam logic [2:0] F3_MAC = 3'b001;
    localparam logic [2:0] F3_RD  = 3'b010;

    wire is_custom0_w = (opcode_opcode_i[6:0] == OPC_CUSTOM0);
    wire [2:0] funct3_w = opcode_opcode_i[14:12];

    // Treat any unexpected encoding as no-op
    wire is_conv_w = opcode_valid_i && is_custom0_w && !opcode_invalid_i;

    // ---------------------------
    // Simple 3-stage FSM
    // ---------------------------
    typedef enum logic [1:0] {
        IDLE    = 2'd0,
        START   = 2'd1,
        EXECUTE = 2'd2,
        STOP    = 2'd3
    } STATE_T;

    STATE_T state_q, state_d;

    logic [2:0]  op_q, op_d;
    logic [31:0] ra_q, ra_d;
    logic [31:0] rb_q, rb_d;

    logic [31:0] result_q, result_d;

    // Accumulator stored as bits; interpreted as float in sim model.
    logic [31:0] acc_q, acc_d;

    // ---------------------------
    // Simulation FP helpers
    // ---------------------------
    function automatic shortreal bits_to_f(input logic [31:0] b);
        bits_to_f = $bitstoshortreal(b);
    endfunction

    function automatic logic [31:0] f_to_bits(input shortreal f);
        f_to_bits = $shortrealtobits(f);
    endfunction

    // ---------------------------
    // Combinational next-state
    // ---------------------------
    always @* begin
        state_d  = state_q;
        op_d     = op_q;
        ra_d     = ra_q;
        rb_d     = rb_q;
        result_d = result_q;
        acc_d    = acc_q;

        // Defaults
        busy_o   = 1'b0;
        valid_o  = 1'b0;
        writeback_o = result_q;

        case (state_q)
            IDLE: begin
                result_d = 32'b0;

                if (is_conv_w) begin
                    op_d = funct3_w;
                    ra_d = opcode_ra_operand_i;
                    rb_d = opcode_rb_operand_i;
                    state_d = START;
                end
            end

            START: begin
                busy_o  = 1'b1;
                state_d = EXECUTE;
            end

            EXECUTE: begin
                busy_o = 1'b1;

                // Simulation reference FP behavior
                shortreal a, b, acc_f, res_f;
                a     = bits_to_f(ra_q);
                b     = bits_to_f(rb_q);
                acc_f = bits_to_f(acc_q);

                res_f = acc_f;

                unique case (op_q)
                    F3_CLR: begin
                        res_f = 0.0;
                        acc_d = f_to_bits(0.0);
                    end

                    F3_MAC: begin
                        res_f = acc_f + (a * b);
                        acc_d = f_to_bits(res_f);
                    end

                    F3_RD: begin
                        res_f = acc_f;
                        // acc stays unchanged
                    end

                    default: begin
                        // no-op
                        res_f = acc_f;
                    end
                endcase

                result_d = f_to_bits(res_f);
                state_d  = STOP;
            end

            STOP: begin
                // One-cycle completion pulse
                valid_o     = 1'b1;
                writeback_o = result_q;

                state_d = IDLE;
            end

            default: state_d = IDLE;
        endcase
    end

    // ---------------------------
    // Sequential state
    // ---------------------------
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state_q  <= IDLE;
            op_q     <= 3'b0;
            ra_q     <= 32'b0;
            rb_q     <= 32'b0;
            result_q <= 32'b0;
            acc_q    <= 32'b0; // 0.0
        end else begin
            state_q  <= state_d;
            op_q     <= op_d;
            ra_q     <= ra_d;
            rb_q     <= rb_d;
            result_q <= result_d;
            acc_q    <= acc_d;
        end
    end

endmodule
