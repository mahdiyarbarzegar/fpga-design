module axi4lite_slave #(
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 5
) (
    input S_AXI_ACLK,
    input S_AXI_ARESETN,

    input  [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input  [                   2 : 0] S_AXI_AWPROT,
    input                             S_AXI_AWVALID,
    output                            S_AXI_AWREADY,

    input  [    C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input  [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input                                 S_AXI_WVALID,
    output                                S_AXI_WREADY,

    output [1 : 0] S_AXI_BRESP,
    output         S_AXI_BVALID,
    input          S_AXI_BREADY,

    input  [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input  [                   2 : 0] S_AXI_ARPROT,
    input                             S_AXI_ARVALID,
    output                            S_AXI_ARREADY,

    output [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output [                   1 : 0] S_AXI_RRESP,
    output                            S_AXI_RVALID,
    input                             S_AXI_RREADY,

    axi4_reg_ifc.AXI reg_ifc
);

    // AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    reg                            axi_awready;
    reg                            axi_wready;
    reg [                   1 : 0] axi_bresp;
    reg                            axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    reg                            axi_arready;
    reg [                   1 : 0] axi_rresp;
    reg                            axi_rvalid;

    // Example-specific design signals
    // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
    // ADDR_LSB is used for addressing 32/64 bit registers/memories
    // ADDR_LSB = 2 for 32 bits (n downto 2)
    // ADDR_LSB = 3 for 64 bits (n downto 3)
    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH / 32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 2;

    // I/O Connections assignments
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    //state machine varibles
    reg [1:0] state_write;
    reg [1:0] state_read;

    //State machine local parameters
    localparam Idle = 2'b00, Raddr = 2'b10, Rdata = 2'b11, Waddr = 2'b10, Wdata = 2'b11;

    // Implement Write state machine
    // Outstanding write transactions are not supported by the slave i.e.,
    // master should assert bready to receive response on or before it starts
    // sending the new transaction
    always_ff @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_awready <= 0;
            axi_wready  <= 0;
            axi_bvalid  <= 0;
            axi_bresp   <= 0;
            axi_awaddr  <= 0;
            state_write <= Idle;
        end else begin
            case (state_write)
                Idle: begin
                    if (S_AXI_ARESETN == 1'b1) begin
                        axi_awready <= 1'b1;
                        axi_wready  <= 1'b1;
                        state_write <= Waddr;
                    end else state_write <= state_write;
                end
                // At this state, slave is ready to receive address along with corresponding
                // control signals and first data packet. Response valid is also handled at
                // this state
                Waddr: begin
                    if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                        axi_awaddr <= S_AXI_AWADDR;
                        if (S_AXI_WVALID) begin
                            axi_awready <= 1'b1;
                            state_write <= Waddr;
                            axi_bvalid  <= 1'b1;
                        end else begin
                            axi_awready <= 1'b0;
                            state_write <= Wdata;
                            if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
                        end
                    end else begin
                        state_write <= state_write;
                        if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
                    end
                end
                // At this state, slave is ready to receive the data packets until the number
                // of transfers is equal to burst length
                Wdata: begin
                    if (S_AXI_WVALID && S_AXI_WREADY) begin
                        state_write <= Waddr;
                        axi_bvalid  <= 1'b1;
                        axi_awready <= 1'b1;
                    end else begin
                        state_write <= state_write;
                        if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Implement read state machine
    always_ff @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            //asserting initial values to all 0's during reset
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rresp   <= 1'b0;
            state_read  <= Idle;
        end else begin
            case (state_read)
                Idle:     //Initial state inidicating reset is done and ready to receive read/write transactions
	              begin
                    if (S_AXI_ARESETN == 1'b1) begin
                        state_read  <= Raddr;
                        axi_arready <= 1'b1;
                    end else state_read <= state_read;
                end
                Raddr:        //At this state, slave is ready to receive address along with corresponding control signals
	              begin
                    if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                        state_read  <= Rdata;
                        axi_araddr  <= S_AXI_ARADDR;
                        axi_rvalid  <= 1'b1;
                        axi_arready <= 1'b0;
                    end else state_read <= state_read;
                end
                Rdata:        //At this state, slave is ready to send the data packets until the number of transfers is equal to burst length
	              begin
                    if (S_AXI_RVALID && S_AXI_RREADY) begin
                        axi_rvalid  <= 1'b0;
                        axi_arready <= 1'b1;
                        state_read  <= Raddr;
                    end else state_read <= state_read;
                end
            endcase
        end
    end

    // Implement memory mapped register select and write logic generation
    // The write data is accepted and written to memory mapped registers when
    // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
    // select byte enables of slave registers while writing.
    // These registers are cleared when reset (active low) is applied.
    // Slave register write enable is asserted when valid address and data are available
    // and the slave is ready to accept the write address and write data.

    assign reg_ifc.wr_addr = (S_AXI_AWVALID) ? S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]
                                                : axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
    assign reg_ifc.wr_data = S_AXI_WDATA;
    assign reg_ifc.wr_strb = S_AXI_WSTRB;
    assign reg_ifc.wr_en = S_AXI_WVALID && S_AXI_WREADY;

    assign reg_ifc.rd_addr = axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
    assign S_AXI_RDATA = reg_ifc.rd_data;

endmodule
