`timescale 1ns / 1ps

module tb_conv_unit;

    logic clk, rst;

    logic        opcode_valid;
    logic [31:0] opcode;
    logic        opcode_invalid;
    logic [31:0] ra, rb;

    // NEW LSU SIGNALS
    logic        lsu_req;
    logic [31:0] lsu_addr;
    logic        lsu_req_ready;
    logic        lsu_data_valid;
    logic [31:0] lsu_data;

    logic        busy;
    logic        valid;
    logic [31:0] writeback;

    localparam input_window_base = 81;

    int K = 9;
    int N = 200;

    logic [31:0] mem [0:2047];

    conv_unit dut (
        .clk_i               (clk),
        .rst_i               (rst),

        .opcode_valid_i      (opcode_valid),
        .opcode_opcode_i     (opcode),
        .opcode_invalid_i    (opcode_invalid),
        .opcode_ra_operand_i (ra),
        .opcode_rb_operand_i (rb),

        .lsu_req_o           (lsu_req),
        .lsu_addr_o          (lsu_addr),
        .lsu_req_ready_i     (lsu_req_ready),
        .lsu_data_valid_i    (lsu_data_valid),
        .lsu_data_i          (lsu_data),

        .busy_o              (busy),
        .valid_o             (valid),
        .writeback_o         (writeback)
    );

    //--------------------------------------------------------------------
    // Clock
    //--------------------------------------------------------------------
    always #10 clk = ~clk;

    //--------------------------------------------------------------------
    // LSU MODEL  (1-cycle latency)
    //--------------------------------------------------------------------
    assign lsu_req_ready = 1;

    always_ff @(posedge clk) begin
        if (rst) begin
            lsu_data_valid <= 0;
            lsu_data <= 0;
        end
        else begin
            lsu_data_valid <= lsu_req;
            if (lsu_req)
                lsu_data <= mem[lsu_addr >> 2];
        end
    end

    //--------------------------------------------------------------------
    // Reference convolution
    //--------------------------------------------------------------------
    function automatic int ref_conv(int off);
        int s = 0;
        for (int i = 0; i < K*K; i++) begin
            s += mem[i] * mem[input_window_base + off + i];
        end
        
        return s;
    endfunction

    int out_idx = 0;

    always @(posedge clk)
        if (valid) begin
            int result = ref_conv(out_idx);
            $display("y[%0d] = %0d", out_idx, writeback);
            if (writeback !== result)
                $fatal("Mismatch at %0d, correct = %0d", out_idx, result);
            out_idx++;
        end

    //--------------------------------------------------------------------
    // Test sequence
    //--------------------------------------------------------------------
    initial begin
        clk = 0;
        rst = 1;
        opcode_valid = 0;
        opcode_invalid = 0;

        #50 rst = 0;

        for (int i = 0; i < K*K; i++)
            mem[i] = i + 1;

        for (int i = 0; i < N; i++)
            mem[input_window_base + i] = i;

        issue_instr(3'b000, 1, 2, 0, 0, input_window_base*4); //CONV.SETBASE X1, X2 (kernel base in x2, input window base in x1)
        issue_instr(3'b001, 4, 3, 0, N, K);   //CONV.SETSIZE X3, X4 (kernel square size in x4, input window size in x3)
        
        #5000;
        
        repeat(N-K+1) begin
            issue_instr(3'b010, 0, 0, 5, 0, 0); //CONV.RUN X5 (store result in x5)
            #5000;
        end

        wait(out_idx == (N - K + 1));
        $display("PASS (K=%0d, N=%0d)", K, N);
        $finish;
    end

    task issue_instr(
        input [2:0] f3,
        input [4:0] rs2, rs1, rd,
        input [31:0] rs1_value, rs2_value);
        opcode_valid = 1;
        opcode = {7'b0,rs2,rs1,f3,rd,7'b0001011}; //FUNC7, RS2, RS1, FUNC3, RD, OPCODE
        
        ra = rs1_value; 
        rb = rs2_value;
        #20;
        opcode_valid = 0;
    endtask

endmodule
