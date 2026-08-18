interface axi4_reg_ifc #(
    parameter int AXI_DATA_WIDTH = 32,
    parameter int REG_ADDR_WIDTH = 3
);

    localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

    logic                        wr_en;
    logic [REG_ADDR_WIDTH-1 : 0] wr_addr;
    logic [AXI_DATA_WIDTH-1 : 0] wr_data;
    logic [AXI_STRB_WIDTH-1 : 0] wr_strb;
    logic [REG_ADDR_WIDTH-1 : 0] rd_addr;
    logic [AXI_DATA_WIDTH-1 : 0] rd_data;

    modport AXI(
        output wr_en,
        output wr_addr,
        output wr_data,
        output wr_strb,
        output rd_addr,
        input rd_data
    );

    modport REG(
        input wr_en,
        input wr_addr,
        input wr_data,
        input wr_strb,
        input rd_addr,
        output rd_data
    );

endinterface
