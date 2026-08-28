module axi4lite_slave #(
    parameter int AXI_DATA_WIDTH,
    parameter int AXI_ADDR_WIDTH
) (
    axi4lite_bus_ifc.SLAVE bus_ifc,
    axi4_reg_ifc.ACCESS    reg_ifc
);

    localparam int STRB_WIDTH = AXI_DATA_WIDTH / 8;
    localparam int ADDR_LSB = (AXI_DATA_WIDTH / 32) + 1;
    localparam int REG_AXI_ADDR_WIDTH = AXI_ADDR_WIDTH - ADDR_LSB;

    initial begin
        assert (AXI_DATA_WIDTH == 32 || AXI_DATA_WIDTH == 64)
        else $error("Unsupported AXI data width");

        assert (AXI_DATA_WIDTH % 8 == 0)
        else $error("AXI data width must be byte aligned");

        assert (AXI_ADDR_WIDTH >= ADDR_LSB + REG_AXI_ADDR_WIDTH)
        else $error("AXI address width is too small");

        assert (reg_ifc.CHANNELS == 1)
        else $error("The CHANNELS for the Register-Interface should be 1!");
    end

    function automatic int addr_alignment(logic [AXI_ADDR_WIDTH-1:0] addr);
        return addr[ADDR_LSB+REG_AXI_ADDR_WIDTH-1:ADDR_LSB];
    endfunction

    // ------------------------------------------------------------------------
    // Write channel storage
    // ------------------------------------------------------------------------
    logic [AXI_ADDR_WIDTH-1:0] axi_awaddr;
    logic [AXI_DATA_WIDTH-1:0] axi_wdata;
    logic [    STRB_WIDTH-1:0] axi_wstrb;

    logic have_aw, have_w;
    logic axi_awready, axi_wready;
    logic aw_handshake, w_handshake;
    logic                      write_fire;

    // ------------------------------------------------------------------------
    // Write response
    // ------------------------------------------------------------------------
    logic [               1:0] axi_bresp;
    logic                      axi_bvalid;

    // ------------------------------------------------------------------------
    // Read channel
    // ------------------------------------------------------------------------
    logic [AXI_ADDR_WIDTH-1:0] axi_araddr;
    logic [               1:0] axi_rresp;
    logic axi_arready, axi_rvalid;
    logic ar_handshake, r_handshake;

    // ========================================================================
    // AXI outputs
    // ========================================================================
    assign bus_ifc.AWREADY = axi_awready;
    assign bus_ifc.WREADY  = axi_wready;
    assign bus_ifc.BRESP   = axi_bresp;
    assign bus_ifc.BVALID  = axi_bvalid;
    assign bus_ifc.ARREADY = axi_arready;
    assign bus_ifc.RRESP   = axi_rresp;
    assign bus_ifc.RVALID  = axi_rvalid;

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

    assign axi_awready     = !have_aw && !axi_bvalid;
    assign axi_wready      = !have_w && !axi_bvalid;
    assign aw_handshake    = bus_ifc.AWVALID && axi_awready;
    assign w_handshake     = bus_ifc.WVALID && axi_wready;
    assign write_fire      = (have_aw || aw_handshake) && (have_w || w_handshake);

    always_ff @(posedge bus_ifc.ACLK) begin
        if (!bus_ifc.ARESETN) begin
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
                axi_awaddr <= bus_ifc.AWADDR;
                have_aw    <= 'b1;
            end

            // ------------------------------------------------------------------------
            // Accept write data
            // ------------------------------------------------------------------------
            if (w_handshake) begin
                axi_wdata <= bus_ifc.WDATA;
                axi_wstrb <= bus_ifc.WSTRB;
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
            if (axi_bvalid && bus_ifc.BREADY) begin
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
    assign reg_ifc.wr_en[0] = write_fire;
    assign reg_ifc.wr_inx[0] = (have_aw) ? addr_alignment(
        axi_awaddr
    ) : addr_alignment(
        bus_ifc.AWADDR
    );
    assign reg_ifc.wr_data[0] = (have_w) ? axi_wdata : bus_ifc.WDATA;
    assign reg_ifc.wr_strb[0] = (have_w) ? axi_wstrb : bus_ifc.WSTRB;

    // ========================================================================
    // Read Channel
    // ========================================================================
    assign axi_arready = !axi_rvalid;
    assign ar_handshake = bus_ifc.ARVALID && axi_arready;
    assign r_handshake = axi_rvalid && bus_ifc.RREADY;

    always_ff @(posedge bus_ifc.ACLK) begin
        if (!bus_ifc.ARESETN) begin
            axi_araddr <= '0;
            axi_rvalid <= '0;
            axi_rresp  <= 2'b00;
        end else begin
            // ------------------------------------------------------------------------
            // Accept read address
            // ------------------------------------------------------------------------
            if (ar_handshake) begin
                axi_araddr <= bus_ifc.ARADDR;
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
    assign bus_ifc.RDATA = reg_ifc.regs[addr_alignment(axi_araddr)];

endmodule : axi4lite_slave
