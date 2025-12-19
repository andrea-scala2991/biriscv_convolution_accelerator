`timescale 1ns / 1ps

module tb_conv_unit;

    logic clk, rst;

    logic        opcode_valid;
    logic [31:0] opcode;
    logic        opcode_invalid;
    logic [31:0] ra, rb;

    logic        mem_rd;
    logic [31:0] mem_addr;
    logic        mem_ack;
    logic [31:0] mem_data;

    logic        busy;
    logic        valid;
    logic [31:0] writeback;

    localparam input_window_base = 81;
    // --------------------------------------------------------------------
    // YOU CAN CHANGE THESE
    // --------------------------------------------------------------------
    int K = 3;     // kernel square size (1..9x9)
    int N = 20;    // input length
    // --------------------------------------------------------------------

    logic [31:0] mem [0:2047];

    conv_unit dut (
        .clk_i               (clk),
        .rst_i               (rst),
        .opcode_valid_i      (opcode_valid),
        .opcode_opcode_i     (opcode),
        .opcode_invalid_i    (opcode_invalid),
        .opcode_ra_operand_i (ra),
        .opcode_rb_operand_i (rb),
        .mem_rd_o            (mem_rd),
        .mem_addr_o          (mem_addr),
        .mem_ack_i           (mem_ack),
        .mem_data_i          (mem_data),
        .busy_o              (busy),
        .valid_o             (valid),
        .writeback_o         (writeback)
    );

    // --------------------------------------------------------------------
    // Clock + Memory handshake
    // --------------------------------------------------------------------
    always #10 clk = ~clk;

    always_ff @(posedge clk) begin
        mem_ack <= mem_rd;
        if (mem_rd)
            mem_data <= mem[mem_addr >> 2];
    end

    // --------------------------------------------------------------------
    // Reference convolution (size = K)
    // kernel values = index+1
    // input values = index
    // --------------------------------------------------------------------
    function int ref_conv(int off);
        int s;
        s = 0;
        for (int i = 0; i < K*K; i++)
            s += (i+1) * mem[input_window_base + off + i];
        return s;
    endfunction

    int out_idx = 0;

    always @(posedge clk)
        if (valid) begin
            $display("y[%0d] = %0d", out_idx, writeback);
            if (writeback !== ref_conv(out_idx))
                $fatal("Mismatch at %0d", out_idx);
            out_idx++;
        end

    // --------------------------------------------------------------------
    // Test sequence
    // --------------------------------------------------------------------
    initial begin
        clk = 0;
        rst = 1;
        opcode_valid = 0;
        opcode_invalid = 0;

        #50 rst = 0;

        // kernel values = index+1
        for (int i = 0; i < K*K; i++)
            mem[i] = i + 1;

        // input values = index
        for (int i = 0; i < N; i++)
            mem[input_window_base + i] = i;

        // program DUT
        issue_instr(3'b000, 0, input_window_base*4);   // base addresses (unchanged assumption)
        issue_instr(3'b001, K, N);        // kernel size + input size
        issue_instr(3'b010, 0, 0);        // run

        wait(out_idx == (N - K + 1));
        $display("PASS (K=%0d, N=%0d)", K, N);
        $finish;
    end

    task issue_instr(input [2:0] f3, input [31:0] rs1, rs2);
        opcode_valid = 1;
        opcode = {7'b0001011,5'd0,5'd0,f3,5'd0,7'b0001011};
        ra = rs1; 
        rb = rs2;
        #20;
        opcode_valid = 0;
    endtask

endmodule
