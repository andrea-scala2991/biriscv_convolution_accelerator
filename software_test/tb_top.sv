`timescale 1ns/1ps

module tb_top;

    // ---------------------------------------------
    // Clock / Reset
    // ---------------------------------------------
    reg clk = 0;
    reg rst = 1;
    always #10 clk = ~clk; // 50MHz

    // ---------------------------------------------
    // Simple Instruction + Data Memory
    // 64-bit IMEM entries, 1024 lines
    // ---------------------------------------------
    reg [63:0] imem [0:1023];
    reg [31:0] dmem [0:1023];



    // ---------------------------------------------
    // AXI wires (instruction)
    // ---------------------------------------------
    wire        axi_i_awready_i = 1'b0;
    wire        axi_i_wready_i  = 1'b0;
    wire        axi_i_bvalid_i  = 1'b0;
    wire [1:0]  axi_i_bresp_i   = 2'b00;
    wire [3:0]  axi_i_bid_i     = 4'b0;

    reg         axi_i_arready_i = 1'b1;
    reg         axi_i_rvalid_i  = 1'b0;
    reg [31:0]  axi_i_rdata_i   = 32'b0;
    reg [1:0]   axi_i_rresp_i   = 2'b00;
    reg [3:0]   axi_i_rid_i     = 4'b0;
    reg         axi_i_rlast_i   = 1'b0;

    // ---------------------------------------------
    // AXI wires (data)
    // ---------------------------------------------
    reg         axi_d_awready_i = 1'b1;
    reg         axi_d_wready_i  = 1'b1;
    reg         axi_d_bvalid_i  = 1'b0;
    wire [1:0]  axi_d_bresp_i   = 2'b00;
    wire [3:0]  axi_d_bid_i     = 4'b0;

    reg         axi_d_arready_i = 1'b1;
    reg         axi_d_rvalid_i  = 1'b0;
    reg [31:0]  axi_d_rdata_i   = 32'b0;
    reg [1:0]   axi_d_rresp_i   = 2'b00;
    wire [3:0]  axi_d_rid_i     = 4'b0;
    reg         axi_d_rlast_i   = 1'b0;

    // ---------------------------------------------
    // DUT
    // ---------------------------------------------
    riscv_top dut (
        .clk_i(clk),
        .rst_i(rst),
        .intr_i(1'b0),
        .reset_vector_i(32'h00000000),

        // Instruction AXI in
        .axi_i_awready_i(axi_i_awready_i),
        .axi_i_wready_i(axi_i_wready_i),
        .axi_i_bvalid_i(axi_i_bvalid_i),
        .axi_i_bresp_i(axi_i_bresp_i),
        .axi_i_bid_i(axi_i_bid_i),
        .axi_i_arready_i(axi_i_arready_i),
        .axi_i_rvalid_i(axi_i_rvalid_i),
        .axi_i_rdata_i(axi_i_rdata_i),
        .axi_i_rresp_i(axi_i_rresp_i),
        .axi_i_rid_i(axi_i_rid_i),
        .axi_i_rlast_i(axi_i_rlast_i),

        // Data AXI in
        .axi_d_awready_i(axi_d_awready_i),
        .axi_d_wready_i(axi_d_wready_i),
        .axi_d_bvalid_i(axi_d_bvalid_i),
        .axi_d_bresp_i(axi_d_bresp_i),
        .axi_d_bid_i(axi_d_bid_i),
        .axi_d_arready_i(axi_d_arready_i),
        .axi_d_rvalid_i(axi_d_rvalid_i),
        .axi_d_rdata_i(axi_d_rdata_i),
        .axi_d_rresp_i(axi_d_rresp_i),
        .axi_d_rid_i(axi_d_rid_i),
        .axi_d_rlast_i(axi_d_rlast_i),

        // AXI OUT ignored
        .axi_i_awvalid_o(),
        .axi_i_awaddr_o(),
        .axi_i_awid_o(),
        .axi_i_awlen_o(),
        .axi_i_awburst_o(),
        .axi_i_wvalid_o(),
        .axi_i_wdata_o(),
        .axi_i_wstrb_o(),
        .axi_i_wlast_o(),
        .axi_i_bready_o(),
        .axi_i_arvalid_o(),
        .axi_i_araddr_o(),
        .axi_i_arid_o(),
        .axi_i_arlen_o(),
        .axi_i_arburst_o(),
        .axi_i_rready_o(),
        .axi_d_awvalid_o(),
        .axi_d_awaddr_o(),
        .axi_d_awid_o(),
        .axi_d_awlen_o(),
        .axi_d_awburst_o(),
        .axi_d_wvalid_o(),
        .axi_d_wdata_o(),
        .axi_d_wstrb_o(),
        .axi_d_wlast_o(),
        .axi_d_bready_o(),
        .axi_d_arvalid_o(),
        .axi_d_araddr_o(),
        .axi_d_arid_o(),
        .axi_d_arlen_o(),
        .axi_d_arburst_o(),
        .axi_d_rready_o()
    );

    // ---------------------------------------------
    // Reset deassert
    // ---------------------------------------------
    initial begin
        $readmemh("testbench_program.mem", dut.u_icache.u_data0.ram);
        #1;
        $display("IMEM[0] = %h", dut.u_icache.u_data0.ram[0]);
        $display("IMEM[1] = %h", dut.u_icache.u_data0.ram[1]);
    
        #10000;
        rst = 0;#20;
     /*   force dut.u_icache.u_data0.ram[0]  = 64'h02_A0_01_13_06_40_00_93;
        force dut.u_icache.u_data0.ram[8]  = 64'h00_20_A0_23_00_00_A1_83;
        force dut.u_icache.u_data0.ram[16] = 64'h00_21_82_33_02_32_02_B3;
        force dut.u_icache.u_data0.ram[24] = 64'h02_22_C3_33_00_23_13_B3;
        force dut.u_icache.u_data0.ram[32] = 64'h00_63_92_63_00_00_00_13;
        force dut.u_icache.u_data0.ram[40] = 64'hFF_DF_F0_6F_00_00_00_13;*/
        
    end
    
    // ---------------------------------------------
    // Finish simulation
    // ---------------------------------------------
    initial begin
            
        #200000;
        $display("Simulation finished.");
        $stop;
    end

endmodule
