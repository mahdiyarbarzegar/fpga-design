module axi4lite_slave #(
    parameter int C_S_AXI_DATA_WIDTH     = 32,
    parameter int C_S_AXI_ADDR_WIDTH     = 5,
    parameter int C_S_AXI_REG_ADDR_WIDTH = 3
) (
    input S_AXI_ACLK,
    input S_AXI_ARESETN,

    input  [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  [                   2:0] S_AXI_AWPROT,
    input                           S_AXI_AWVALID,
    output                          S_AXI_AWREADY,

    input  [    C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input                               S_AXI_WVALID,
    output                              S_AXI_WREADY,

    output [1:0] S_AXI_BRESP,
    output       S_AXI_BVALID,
    input        S_AXI_BREADY,

    input  [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  [                   2:0] S_AXI_ARPROT,
    input                           S_AXI_ARVALID,
    output                          S_AXI_ARREADY,

    output [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output [                   1:0] S_AXI_RRESP,
    output                          S_AXI_RVALID,
    input                           S_AXI_RREADY,

    axi4_reg_ifc.AXI reg_ifc
);

    localparam int STRB_WIDTH = C_S_AXI_DATA_WIDTH / 8;
    localparam int ADDR_LSB = (C_S_AXI_DATA_WIDTH / 32) + 1;

    initial begin
        assert (C_S_AXI_DATA_WIDTH == 32 || C_S_AXI_DATA_WIDTH == 64)
        else $error("Unsupported AXI data width");

        assert (C_S_AXI_DATA_WIDTH % 8 == 0)
        else $error("AXI data width must be byte aligned");

        assert (C_S_AXI_ADDR_WIDTH >= ADDR_LSB + C_S_AXI_REG_ADDR_WIDTH)
        else $error("AXI address width is too small");
    end

    // ------------------------------------------------------------------------
    // Write channel storage
    // ------------------------------------------------------------------------
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_wdata;
    logic [        STRB_WIDTH-1:0] axi_wstrb;

    logic have_aw, have_w;
    logic axi_awready, axi_wready;
    logic aw_handshake, w_handshake;
    logic                          write_fire;

    // ------------------------------------------------------------------------
    // Write response
    // ------------------------------------------------------------------------
    logic [                   1:0] axi_bresp;
    logic                          axi_bvalid;

    // ------------------------------------------------------------------------
    // Read channel
    // ------------------------------------------------------------------------
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    logic [                   1:0] axi_rresp;
    logic axi_arready, axi_rvalid;
    logic ar_handshake, r_handshake;

    // ========================================================================
    // AXI outputs
    // ========================================================================
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // ========================================================================
    // Write Channel
    // ========================================================================
    /*
     * AW and W are independent AXI channels.
     *
     * We accept each channel independently and remember the transaction
     * until both address and data have been received.
     *
     * Only one write transaction may be outstanding.
     * A new write is not accepted until the previous B response is consumed.
     */

    assign axi_awready   = !have_aw && !axi_bvalid;
    assign axi_wready    = !have_w && !axi_bvalid;
    assign aw_handshake  = S_AXI_AWVALID && axi_awready;
    assign w_handshake   = S_AXI_WVALID && axi_wready;
    assign write_fire    = (have_aw || aw_handshake) && (have_w || w_handshake);

    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awaddr <= 'b0;
            axi_wdata  <= 'b0;
            axi_wstrb  <= 'b0;
            have_aw    <= 'b0;
            have_w     <= 'b0;
            axi_bvalid <= 'b0;
            axi_bresp  <= 2'b00;
        end else begin
            // ------------------------------------------------------------------------
            // Accept write address
            // ------------------------------------------------------------------------
            if (aw_handshake) begin
                axi_awaddr <= S_AXI_AWADDR;
                have_aw    <= 'b1;
            end

            // ------------------------------------------------------------------------
            // Accept write data
            // ------------------------------------------------------------------------
            if (w_handshake) begin
                axi_wdata <= S_AXI_WDATA;
                axi_wstrb <= S_AXI_WSTRB;
                have_w    <= 'b1;
            end

            // ------------------------------------------------------------------------
            // Both address and data are available
            // Generate the register write transaction.
            // ------------------------------------------------------------------------
            if (write_fire) begin
                axi_bvalid <= 'b1;
                axi_bresp  <= 2'b00;
                have_aw    <= 'b0;
                have_w     <= 'b0;
            end

            // ------------------------------------------------------------------------
            // Write response accepted
            // ------------------------------------------------------------------------
            if (axi_bvalid && S_AXI_BREADY) begin
                axi_bvalid <= 'b0;
            end
        end
    end

    // ========================================================================
    // Register Write Interface
    // ========================================================================
    /*
     * A register write occurs when both AW and W have been accepted.
     *
     * The expression below also handles the case where AW and W are
     * accepted in the same clock cycle.
     */
    assign reg_ifc.wr_en = write_fire;
    assign reg_ifc.wr_addr = (have_aw)?
                                        axi_awaddr[ADDR_LSB+C_S_AXI_REG_ADDR_WIDTH-1:ADDR_LSB]:
                                        S_AXI_AWADDR[ADDR_LSB+C_S_AXI_REG_ADDR_WIDTH-1:ADDR_LSB];
    assign reg_ifc.wr_data = (have_w) ? axi_wdata : S_AXI_WDATA;
    assign reg_ifc.wr_strb = (have_w) ? axi_wstrb : S_AXI_WSTRB;

    // ========================================================================
    // Read Channel
    // ========================================================================
    assign axi_arready = !axi_rvalid;
    assign ar_handshake = S_AXI_ARVALID && axi_arready;
    assign r_handshake = axi_rvalid && S_AXI_RREADY;

    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_araddr <= '0;
            axi_rvalid <= '0;
            axi_rresp  <= 2'b00;
        end else begin
            // ------------------------------------------------------------------------
            // Accept read address
            // ------------------------------------------------------------------------
            if (ar_handshake) begin
                axi_araddr <= S_AXI_ARADDR;
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00;
            end
            // ------------------------------------------------------------------------
            // Read response accepted
            // ------------------------------------------------------------------------
            if (r_handshake) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // ========================================================================
    // Register Read Interface
    // ========================================================================
    assign reg_ifc.rd_addr = axi_araddr[ADDR_LSB+C_S_AXI_REG_ADDR_WIDTH-1:ADDR_LSB];
    assign S_AXI_RDATA     = reg_ifc.rd_data;

endmodule : axi4lite_slave
