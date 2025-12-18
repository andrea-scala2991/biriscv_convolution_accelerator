`timescale 1ns / 1ps

module conv_unit #
(
    parameter MAX_K        = 9,
    parameter MAX_K_ELEMS  = MAX_K*MAX_K,
    parameter MAX_INPUT_W  = 4096
)
(
    input  logic        clk_i,
    input  logic        rst_i,

    // Issued instruction
    input  logic        opcode_valid_i,
    input  logic [31:0] opcode_opcode_i,
    input  logic        opcode_invalid_i,
    input  logic [31:0] opcode_ra_operand_i,
    input  logic [31:0] opcode_rb_operand_i,

    // LSU interface
    output logic        mem_rd_o,
    output logic [31:0] mem_addr_o,
    input  logic        mem_ack_i,
    input  logic [31:0] mem_data_i,

    // Writeback
    output logic        busy_o,
    output logic        valid_o,
    output logic [31:0] writeback_o
);

    /* ---------------- Decode ---------------- */

    localparam OPC_CUSTOM0 = 7'b0001011;

    wire is_custom =
        opcode_valid_i &&
        !opcode_invalid_i &&
        opcode_opcode_i[6:0] == OPC_CUSTOM0;

    wire [2:0] funct3 = opcode_opcode_i[14:12];

    localparam F3_SETBASE = 3'b000;
    localparam F3_SETSIZE = 3'b001;
    localparam F3_RUN     = 3'b010;

    /* ---------------- State machine ---------------- */

    typedef enum logic [2:0] {
        IDLE,
        LOAD_KERNEL,
        LOAD_INPUT,
        COMPUTE,
        DONE
    } state_t;

    state_t state_q, state_d;

    /* ---------------- Configuration registers ---------------- */

    logic [31:0] kernel_base_q;
    logic [31:0] input_base_q;

    logic [6:0]  kernel_elems_q;
    logic [11:0] input_words_q;

    /* ---------------- Local storage ---------------- */

    logic [31:0] kernel_mem [0:MAX_K_ELEMS-1];
    logic [31:0] input_mem  [0:MAX_INPUT_W-1];

    logic [11:0] idx_q, idx_d;

    /* ---------------- MAC datapath ---------------- */

    logic [63:0] sum_q;

    integer i;
    always_comb begin
        sum_q = 64'd0;
        for (i = 0; i < MAX_K_ELEMS; i = i + 1)
            if (i < kernel_elems_q)
                sum_q += kernel_mem[i] * input_mem[i];
    end

    /* ---------------- FSM ---------------- */

    always_comb begin
        state_d    = state_q;
        idx_d      = idx_q;

        mem_rd_o   = 1'b0;
        mem_addr_o = 32'b0;

        busy_o     = 1'b1;
        valid_o    = 1'b0;
        writeback_o = sum_q[31:0];

        case (state_q)
            IDLE: begin
                busy_o = 1'b0;
                idx_d  = 0;
            
                if (is_custom) begin
                    case (funct3)
            
                        // Pure configuration instructions
                        F3_SETBASE: begin
                            // registers updated in sequential block
                            state_d = IDLE;
                        end
            
                        F3_SETSIZE: begin
                            state_d = IDLE;
                        end
            
                        // Start execution only if configured
                        F3_RUN: begin
                            if (kernel_elems_q != 0 && input_words_q != 0)
                                state_d = LOAD_KERNEL;
                            else
                                state_d = IDLE; // or raise error flag
                        end
            
                        default: state_d = IDLE;
                    endcase
                end
            end
            
            LOAD_KERNEL: begin
                mem_rd_o   = 1'b1;
                mem_addr_o = kernel_base_q + (idx_q << 2);

                if (mem_ack_i) begin
                    kernel_mem[idx_q] = mem_data_i;
                    idx_d = idx_q + 1;
                    if (idx_q == kernel_elems_q - 1) begin
                        idx_d   = 0;
                        state_d = LOAD_INPUT;
                    end
                end
            end

            LOAD_INPUT: begin
                mem_rd_o   = 1'b1;
                mem_addr_o = input_base_q + (idx_q << 2);

                if (mem_ack_i) begin
                    input_mem[idx_q] = mem_data_i;
                    idx_d = idx_q + 1;
                    if (idx_q == input_words_q - 1)
                        state_d = COMPUTE;
                end
            end

            COMPUTE: begin
                state_d = DONE;
            end

            DONE: begin
                valid_o = 1'b1;
                state_d = IDLE;
            end
        endcase
    end

    /* ---------------- Sequential ---------------- */

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state_q        <= IDLE;
            idx_q          <= 0;
            kernel_base_q  <= 0;
            input_base_q   <= 0;
            kernel_elems_q <= 0;
            input_words_q  <= 0;
        end else begin
            state_q <= state_d;
            idx_q   <= idx_d;

            if (is_custom && funct3 == F3_SETBASE) begin
                kernel_base_q <= opcode_ra_operand_i;
                input_base_q  <= opcode_rb_operand_i;
            end

            if (is_custom && funct3 == F3_SETSIZE) begin
                kernel_elems_q <= opcode_ra_operand_i[6:0];
                input_words_q  <= opcode_rb_operand_i[11:0];
            end
        end
    end

endmodule
