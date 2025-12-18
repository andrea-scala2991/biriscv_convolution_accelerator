`timescale 1ns / 1ps

module adder_tree #
(
    parameter N = 81,
    parameter W = 64
)
(
    input  logic            clk_i,
    input  logic [W-1:0]    in [0:N-1],
    output logic [W-1:0]    out
);

    localparam STAGE1 = (N+1)/2;
    localparam STAGE2 = (STAGE1+1)/2;
    localparam STAGE3 = (STAGE2+1)/2;
    localparam STAGE4 = (STAGE3+1)/2;
    localparam STAGE5 = (STAGE4+1)/2;
    localparam STAGE6 = (STAGE5+1)/2;

    logic [W-1:0] s1 [0:STAGE1-1];
    logic [W-1:0] s2 [0:STAGE2-1];
    logic [W-1:0] s3 [0:STAGE3-1];
    logic [W-1:0] s4 [0:STAGE4-1];
    logic [W-1:0] s5 [0:STAGE5-1];
    logic [W-1:0] s6 [0:STAGE6-1];

    integer i;

    // Stage 1
    always @(posedge clk_i) begin
        for (i=0; i<STAGE1; i=i+1)
            s1[i] <= in[2*i] + ((2*i+1 < N) ? in[2*i+1] : 0);
    end

    // Stage 2
    always @(posedge clk_i) begin
        for (i=0; i<STAGE2; i=i+1)
            s2[i] <= s1[2*i] + ((2*i+1 < STAGE1) ? s1[2*i+1] : 0);
    end

    // Stage 3
    always @(posedge clk_i) begin
        for (i=0; i<STAGE3; i=i+1)
            s3[i] <= s2[2*i] + ((2*i+1 < STAGE2) ? s2[2*i+1] : 0);
    end

    // Stage 4
    always @(posedge clk_i) begin
        for (i=0; i<STAGE4; i=i+1)
            s4[i] <= s3[2*i] + ((2*i+1 < STAGE3) ? s3[2*i+1] : 0);
    end

    // Stage 5
    always @(posedge clk_i) begin
        for (i=0; i<STAGE5; i=i+1)
            s5[i] <= s4[2*i] + ((2*i+1 < STAGE4) ? s4[2*i+1] : 0);
    end

    // Stage 6
    always @(posedge clk_i) begin
        for (i=0; i<STAGE6; i=i+1)
            s6[i] <= s5[2*i] + ((2*i+1 < STAGE5) ? s5[2*i+1] : 0);
    end

    assign out = s6[0];

endmodule
