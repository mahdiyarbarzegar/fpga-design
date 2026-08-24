interface axi4_reg_ifc #(
    parameter int DATA_WIDTH,
    parameter int ADDR_WIDTH,
    parameter int NUM_REGS,
    parameter int CHANNELS   = 1
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam int ADDR_LSB = $clog2(DATA_WIDTH / 8);
    localparam int INDEX_WIDTH = ADDR_WIDTH - ADDR_LSB;

    logic                     wr_en  [CHANNELS];
    logic [INDEX_WIDTH-1 : 0] wr_inx [CHANNELS];
    logic [ DATA_WIDTH-1 : 0] wr_data[CHANNELS];
    logic [ STRB_WIDTH-1 : 0] wr_strb[CHANNELS];

    logic [   DATA_WIDTH-1:0] regs   [NUM_REGS];

    modport ACCESS(output wr_en, output wr_inx, output wr_data, output wr_strb, input regs);

    modport STORAGE(input wr_en, input wr_inx, input wr_data, input wr_strb, output regs);

endinterface
