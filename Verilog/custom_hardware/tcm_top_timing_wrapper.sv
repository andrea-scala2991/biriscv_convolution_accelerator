module tcm_top_timing_wrapper (
    input  logic        clk_i,
    input  logic        rst_i
);

    // ------------------------------------------------------------
    // Reset / boot
    // ------------------------------------------------------------
    logic [31:0] reset_vector;
    assign reset_vector = 32'h00000000;

    // ------------------------------------------------------------
    // Tie-offs for AXI (no external memory)
    // ------------------------------------------------------------
    logic        axi_i_awready;
    logic        axi_i_wready;
    logic        axi_i_bvalid;
    logic [1:0]  axi_i_bresp;
    logic        axi_i_arready;
    logic        axi_i_rvalid;
    logic [31:0] axi_i_rdata;
    logic [1:0]  axi_i_rresp;

    logic        axi_t_awvalid;
    logic [31:0] axi_t_awaddr;
    logic [3:0]  axi_t_awid;
    logic [7:0]  axi_t_awlen;
    logic [1:0]  axi_t_awburst;
    logic        axi_t_wvalid;
    logic [31:0] axi_t_wdata;
    logic [3:0]  axi_t_wstrb;
    logic        axi_t_wlast;
    logic        axi_t_bready;
    logic        axi_t_arvalid;
    logic [31:0] axi_t_araddr;
    logic [3:0]  axi_t_arid;
    logic [7:0]  axi_t_arlen;
    logic [1:0]  axi_t_arburst;
    logic        axi_t_rready;

    // All AXI inputs tied to zero
    assign axi_i_awready = 1'b0;
    assign axi_i_wready  = 1'b0;
    assign axi_i_bvalid  = 1'b0;
    assign axi_i_bresp   = 2'b00;
    assign axi_i_arready = 1'b0;
    assign axi_i_rvalid  = 1'b0;
    assign axi_i_rdata   = 32'b0;
    assign axi_i_rresp   = 2'b00;

    assign axi_t_awvalid = 1'b0;
    assign axi_t_awaddr  = 32'b0;
    assign axi_t_awid    = 4'b0;
    assign axi_t_awlen   = 8'b0;
    assign axi_t_awburst = 2'b0;
    assign axi_t_wvalid  = 1'b0;
    assign axi_t_wdata   = 32'b0;
    assign axi_t_wstrb   = 4'b0;
    assign axi_t_wlast   = 1'b0;
    assign axi_t_bready  = 1'b0;
    assign axi_t_arvalid = 1'b0;
    assign axi_t_araddr  = 32'b0;
    assign axi_t_arid    = 4'b0;
    assign axi_t_arlen   = 8'b0;
    assign axi_t_arburst = 2'b0;
    assign axi_t_rready  = 1'b0;

    // ------------------------------------------------------------
    // Instantiate CPU top
    // ------------------------------------------------------------
    riscv_tcm_top uut (
        .clk_i            (clk_i),
        .rst_i            (rst_i),
        .rst_cpu_i        (rst_i),

        // AXI input (external memory)
        .axi_i_awready_i  (axi_i_awready),
        .axi_i_wready_i   (axi_i_wready),
        .axi_i_bvalid_i   (axi_i_bvalid),
        .axi_i_bresp_i    (axi_i_bresp),
        .axi_i_arready_i  (axi_i_arready),
        .axi_i_rvalid_i   (axi_i_rvalid),
        .axi_i_rdata_i    (axi_i_rdata),
        .axi_i_rresp_i    (axi_i_rresp),

        // AXI input (TCM slave side)
        .axi_t_awvalid_i  (axi_t_awvalid),
        .axi_t_awaddr_i   (axi_t_awaddr),
        .axi_t_awid_i     (axi_t_awid),
        .axi_t_awlen_i    (axi_t_awlen),
        .axi_t_awburst_i  (axi_t_awburst),
        .axi_t_wvalid_i   (axi_t_wvalid),
        .axi_t_wdata_i    (axi_t_wdata),
        .axi_t_wstrb_i    (axi_t_wstrb),
        .axi_t_wlast_i    (axi_t_wlast),
        .axi_t_bready_i   (axi_t_bready),
        .axi_t_arvalid_i  (axi_t_arvalid),
        .axi_t_araddr_i   (axi_t_araddr),
        .axi_t_arid_i     (axi_t_arid),
        .axi_t_arlen_i    (axi_t_arlen),
        .axi_t_arburst_i  (axi_t_arburst),
        .axi_t_rready_i   (axi_t_rready),

        // Interrupts
        .intr_i           (32'b0)

        // AXI outputs are intentionally left unconnected
        // (safe because inputs are tied off)
    );

    (* mark_debug = "true" *)
    logic [31:0] pc_debug;
    
    assign pc_debug = uut.u_core.u_frontend.u_fetch.pc_f_q;
    

endmodule
