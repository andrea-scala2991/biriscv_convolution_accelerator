`timescale 1ns/1ps

module conv_unit #
(
    parameter MAX_K        = 9,
    parameter MAX_K_ELEMS  = MAX_K*MAX_K,
    parameter MAX_INPUT_W  = 4096
)
(
    input  logic        clk_i,
    input  logic        rst_i,

    //INSTRUCTION DECODE
    input  logic        opcode_valid_i,
    input  logic [31:0] opcode_opcode_i,
    input  logic        opcode_invalid_i,
    input  logic [31:0] opcode_ra_operand_i,
    input  logic [31:0] opcode_rb_operand_i,

    //LSU HANDSHAKE    
    output logic        lsu_req_o,
    output logic [31:0] lsu_addr_o,
    input  logic        lsu_req_ready_i,
    
    input  logic        lsu_data_valid_i,
    input  logic [31:0] lsu_data_i,

    //OUTPUTS    
    output logic        busy_o,
    output logic        valid_o,
    output logic [31:0] writeback_o
);

/* ---------- decode ---------- */
localparam OPC_CUSTOM0 = 7'b0001011;
wire is_custom =
    opcode_valid_i &&
    !opcode_invalid_i &&
    opcode_opcode_i[6:0] == OPC_CUSTOM0;

wire [2:0] funct3 = opcode_opcode_i[14:12];

localparam F3_SETBASE = 3'b000;
localparam F3_SETSIZE = 3'b001;
localparam F3_RUN     = 3'b010;

/* ---------- FSM ---------- */
typedef enum logic [3:0]
{
    IDLE,
    LOAD_KERNEL_REQ,
    LOAD_KERNEL_WRITE,
    LOAD_INPUT_REQ,
    LOAD_INPUT_WRITE,
    PREP_REQ,
    PREP_WAIT,
    PREP_LATCH,
    MAC_STAGE1,
    MAC_STAGE2,
    MAC_DONE
} state_t;

state_t state_q, state_d;

/* ---------- cfg ---------- */
logic [31:0] kernel_base_q, input_base_q;
logic [3:0]  kernel_dim_q;
logic [6:0]  kernel_elems_q;
logic [11:0] input_words_q;

logic [11:0] slide_q, slide_d;
always_comb kernel_elems_q = kernel_dim_q * kernel_dim_q;

/* ---------- BRAMs ---------- */
logic [$clog2(MAX_K_ELEMS)-1:0]  k_addr;
logic [31:0] k_dout;
logic        k_en;
logic [31:0] k_din;
logic        k_we;

BRAM #(
    .WORD_SIZE(32),
    .RAM_DEPTH(MAX_K_ELEMS)
) kernel_mem (
    .clk(clk_i),
    .addr_a(k_addr),
    .din_a (k_din),
    .dout_a(k_dout),
    .we_a  (k_we),
    .en_a  (k_en)
);

logic [$clog2(MAX_INPUT_W)-1:0]  i_addr;
logic [31:0] i_dout;
logic        i_en;
logic [31:0] i_din;
logic        i_we;

BRAM #(
    .WORD_SIZE(32),
    .RAM_DEPTH(MAX_INPUT_W)
) input_mem (
    .clk(clk_i),
    .addr_a(i_addr),
    .din_a (i_din),
    .dout_a(i_dout),
    .we_a  (i_we),
    .en_a  (i_en)
);

/* ---------- locals ---------- */
logic [31:0] kernel_reg [0:MAX_K_ELEMS-1];
logic [31:0] window_reg [0:MAX_K_ELEMS-1];

logic [6:0] prep_idx_q, prep_idx_d;
logic [11:0] rd_idx_q,  rd_idx_d;

logic kernel_loaded_q, kernel_loaded_d;
logic input_loaded_q,  input_loaded_d;

logic out_valid_q, out_valid_d;
logic [31:0] out_data_q, out_data_d;

logic [6:0]  prep_idx_hold_q, prep_idx_hold_d;

logic [31:0] load_data_q;
logic [11:0] load_idx_q;

/* ---------- MAC ---------- */
logic [63:0] prod [0:MAX_K_ELEMS-1];

generate
    genvar k;
    for (k = 0; k < MAX_K_ELEMS; k++) begin
        (* use_dsp = "yes" *)
        assign prod[k] =
            (k < kernel_elems_q) ?
                (kernel_reg[k] * window_reg[k]) :
                64'd0;
    end
endgenerate

logic [63:0] acc;
always_comb begin
    acc = 0;
    for (int i = 0; i < MAX_K_ELEMS; i++)
        acc += prod[i];
end

/* ---------- FSM COMB ---------- */
always_comb begin
    state_d    = state_q;
    rd_idx_d   = rd_idx_q;
    prep_idx_d = prep_idx_q;
    slide_d    = slide_q;

    kernel_loaded_d = kernel_loaded_q;
    input_loaded_d  = input_loaded_q;

    lsu_req_o  = 0;
    lsu_addr_o = 0;

    i_en = 0;
    k_en = 0;
    k_addr = 0;
    i_addr = 0;
    k_we = 0; 
    k_din = 0;
    i_we = 0;
    i_din = 0;
    
    prep_idx_hold_d = prep_idx_hold_q;

    out_valid_d = out_valid_q;
    out_data_d  = out_data_q;

    busy_o = (state_q != IDLE);

    case (state_q)

        IDLE: begin
            out_valid_d = 0;
            if (is_custom && funct3==F3_RUN) begin
                if (!kernel_loaded_q)
                    state_d = LOAD_KERNEL_REQ;
                else if (!input_loaded_q)
                    state_d = LOAD_INPUT_REQ;
                else begin
                    prep_idx_d = 0;
                    state_d = PREP_REQ;
                end
            end
        end
        
        /* -------- kernel load -------- */
        LOAD_KERNEL_REQ: begin
            lsu_req_o  = 1;
            lsu_addr_o = kernel_base_q + (rd_idx_q<<2);
            if (lsu_req_ready_i && lsu_data_valid_i) begin
                state_d = LOAD_KERNEL_WRITE;
            end
        end
        
        LOAD_KERNEL_WRITE: begin
            load_data_q <= lsu_data_i;
            load_idx_q  <= rd_idx_q;

            k_en   = 1;
            k_we   = 1;
            k_addr = rd_idx_q;
            k_din  = lsu_data_i;

            rd_idx_d = rd_idx_q + 1;
        
            if (rd_idx_q+1 == kernel_elems_q) begin
                kernel_loaded_d = 1;
                rd_idx_d = 0;
                state_d = input_loaded_q ? IDLE : LOAD_INPUT_REQ;
            end else
                state_d = LOAD_KERNEL_REQ;
        end
        
        /* -------- input load -------- */
        LOAD_INPUT_REQ: begin
            lsu_req_o  = 1;
            lsu_addr_o = input_base_q + (rd_idx_q<<2);
            if (lsu_req_ready_i && lsu_data_valid_i)
                state_d = LOAD_INPUT_WRITE;
        end
        
        LOAD_INPUT_WRITE: begin
            load_data_q <= lsu_data_i;
            load_idx_q  <= rd_idx_q;

            i_en   = 1;
            i_we   = 1;
            i_addr = rd_idx_q;
            i_din  = lsu_data_i;
        
            rd_idx_d = rd_idx_q + 1;
        
            if (rd_idx_q+1 == input_words_q) begin
                input_loaded_d = 1;
                rd_idx_d = 0;
                slide_d  = 0;
                state_d  = IDLE;
            end else
                state_d = LOAD_INPUT_REQ;
        end
        
        /* -------- sliding window prep -------- */
        PREP_REQ: begin
            if (prep_idx_q < kernel_elems_q) begin
                i_en = 1;
                i_addr = slide_q + prep_idx_q;
                prep_idx_hold_d = prep_idx_q;
                state_d = PREP_WAIT;
            end else
                state_d = MAC_STAGE1;
        end
        
        PREP_WAIT: begin
            state_d = PREP_LATCH;
        end

        PREP_LATCH: begin
            prep_idx_d = prep_idx_q + 1;
            state_d = PREP_REQ;
        end
        
        MAC_STAGE1: state_d = MAC_STAGE2;
        MAC_STAGE2: state_d = MAC_DONE;

        MAC_DONE: begin
            out_valid_d = 1;
            out_data_d  = acc[31:0];
            state_d     = IDLE;
        end
    endcase
end

/* ---------- sequential ---------- */
always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        state_q <= IDLE;
        rd_idx_q <= 0;
        prep_idx_q <= 0;
        slide_q <= 0;
        kernel_loaded_q <= 0;
        input_loaded_q  <= 0;
        out_valid_q <= 0;
        out_data_q <= 0;
        kernel_base_q <= 0;
        input_base_q  <= 0;
        kernel_dim_q  <= 0;
        input_words_q <= 0;
        prep_idx_hold_q <= 0;
    end
    else begin
        state_q <= state_d;
        rd_idx_q <= rd_idx_d;
        prep_idx_q <= prep_idx_d;
        slide_q <= slide_d;
        kernel_loaded_q <= kernel_loaded_d;
        input_loaded_q  <= input_loaded_d;
        out_valid_q <= out_valid_d;
        out_data_q  <= out_data_d;
        prep_idx_hold_q <= prep_idx_hold_d;

        if (out_valid_d)
            slide_q <= slide_q + 1;

        if (is_custom && funct3==F3_SETBASE) begin
            kernel_base_q <= opcode_ra_operand_i;
            input_base_q  <= opcode_rb_operand_i;
            kernel_loaded_q <= 0;
            input_loaded_q  <= 0;
            slide_q <= 0;
        end

        if (is_custom && funct3==F3_SETSIZE) begin
            kernel_dim_q  <= opcode_rb_operand_i[3:0];
            input_words_q <= opcode_ra_operand_i[11:0];
            kernel_loaded_q <= 0;
            input_loaded_q  <= 0;
            slide_q <= 0;
        end

        // ---- real population of kernel_reg[] ----
        if (state_q == LOAD_KERNEL_WRITE)
            kernel_reg[load_idx_q] <= lsu_data_i;

        // ---- sliding window register load aligned ----
        if (state_q == PREP_LATCH)
            window_reg[prep_idx_hold_q] <= i_dout;
    end
end

assign valid_o     = out_valid_q;
assign writeback_o = out_data_q;

endmodule
