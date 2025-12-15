module timing_wrapper (
    input  logic clk,
    input  logic rst,

    // Observable output to prevent optimization
    output logic [31:0] pc_debug
);

    // ---------------------------
    // AXI STUBS
    // ---------------------------
    logic        axi_awready = 1'b1;
    logic        axi_wready  = 1'b1;
    logic        axi_bvalid  = 1'b1;
    logic [1:0]  axi_bresp   = 2'b00;
    logic [3:0]  axi_bid     = 4'h0;

    logic        axi_arready = 1'b1;
    logic        axi_rvalid  = 1'b1;
    logic [31:0] axi_rdata   = 32'h00000013;   // NOP
    logic [1:0]  axi_rresp   = 2'b00;
    logic [3:0]  axi_rid     = 4'h0;
    logic        axi_rlast   = 1'b1;

    logic        intr = 1'b0;
    logic [31:0] reset_vector = 32'h80000000;

    // ---------------------------
    // Instantiate CPU
    // ---------------------------
    (* DONT_TOUCH = "TRUE" *)
    riscv_top uut (
        .clk_i(clk),
        .rst_i(rst),

        // Instruction AXI inputs
        .axi_i_awready_i(axi_awready),
        .axi_i_wready_i (axi_wready),
        .axi_i_bvalid_i (axi_bvalid),
        .axi_i_bresp_i  (axi_bresp),
        .axi_i_bid_i    (axi_bid),
        .axi_i_arready_i(axi_arready),
        .axi_i_rvalid_i (axi_rvalid),
        .axi_i_rdata_i  (axi_rdata),
        .axi_i_rresp_i  (axi_rresp),
        .axi_i_rid_i    (axi_rid),
        .axi_i_rlast_i  (axi_rlast),

        // Data AXI inputs
        .axi_d_awready_i(axi_awready),
        .axi_d_wready_i (axi_wready),
        .axi_d_bvalid_i (axi_bvalid),
        .axi_d_bresp_i  (axi_bresp),
        .axi_d_bid_i    (axi_bid),
        .axi_d_arready_i(axi_arready),
        .axi_d_rvalid_i (axi_rvalid),
        .axi_d_rdata_i  (axi_rdata),
        .axi_d_rresp_i  (axi_rresp),
        .axi_d_rid_i    (axi_rid),
        .axi_d_rlast_i  (axi_rlast),

        .intr_i(intr),
        .reset_vector_i(reset_vector),

        // AXI outputs ignored
        .axi_i_awvalid_o(),
        .axi_i_awaddr_o (),
        .axi_i_awid_o   (),
        .axi_i_awlen_o  (),
        .axi_i_awburst_o(),
        .axi_i_wvalid_o (),
        .axi_i_wdata_o  (),
        .axi_i_wstrb_o  (),
        .axi_i_wlast_o  (),
        .axi_i_bready_o (),
        .axi_i_arvalid_o(),
        .axi_i_araddr_o (),
        .axi_i_arid_o   (),
        .axi_i_arlen_o  (),
        .axi_i_arburst_o(),
        .axi_i_rready_o (),

        .axi_d_awvalid_o(),
        .axi_d_awaddr_o (),
        .axi_d_awid_o   (),
        .axi_d_awlen_o  (),
        .axi_d_awburst_o(),
        .axi_d_wvalid_o (),
        .axi_d_wdata_o  (),
        .axi_d_wstrb_o  (),
        .axi_d_wlast_o  (),
        .axi_d_bready_o (),
        .axi_d_arvalid_o(),
        .axi_d_araddr_o (),
        .axi_d_arid_o   (),
        .axi_d_arlen_o  (),
        .axi_d_arburst_o(),
        .axi_d_rready_o ()
    );

    // ---------------------------
    // Export internal signal
    // ---------------------------
    // Expose instruction address (PC) to force Vivado to keep the core
    assign pc_debug = uut.u_core.u_frontend.u_fetch.pc_f_q;

endmodule