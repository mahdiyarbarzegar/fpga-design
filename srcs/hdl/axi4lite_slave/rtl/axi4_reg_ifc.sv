interface axi4_reg_ifc #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 5
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam int ADDR_LSB = (DATA_WIDTH / 32) + 1;
    localparam int REG_ADDR_WIDTH = ADDR_WIDTH - ADDR_LSB;

    logic                        wr_en;
    logic [REG_ADDR_WIDTH-1 : 0] wr_addr;
    logic [    DATA_WIDTH-1 : 0] wr_data;
    logic [    STRB_WIDTH-1 : 0] wr_strb;
    logic [REG_ADDR_WIDTH-1 : 0] rd_addr;
    logic [    DATA_WIDTH-1 : 0] rd_data;

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
