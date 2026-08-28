interface axi4_reg_ifc #(
    parameter int AXI_DATA_WIDTH,
    parameter int AXI_ADDR_WIDTH,
    parameter int NUM_REGS,
    parameter int CHANNELS       = 1
);

    localparam int STRB_WIDTH = AXI_DATA_WIDTH / 8;
    localparam int ADDR_LSB = $clog2(AXI_DATA_WIDTH / 8);
    localparam int INDEX_WIDTH = AXI_ADDR_WIDTH - ADDR_LSB;

    logic                        wr_en  [CHANNELS];
    logic [   INDEX_WIDTH-1 : 0] wr_inx [CHANNELS];
    logic [AXI_DATA_WIDTH-1 : 0] wr_data[CHANNELS];
    logic [    STRB_WIDTH-1 : 0] wr_strb[CHANNELS];

    logic [  AXI_DATA_WIDTH-1:0] regs   [NUM_REGS];

    modport ACCESS(output wr_en, output wr_inx, output wr_data, output wr_strb, input regs);

    modport STORAGE(input wr_en, input wr_inx, input wr_data, input wr_strb, output regs);

endinterface
