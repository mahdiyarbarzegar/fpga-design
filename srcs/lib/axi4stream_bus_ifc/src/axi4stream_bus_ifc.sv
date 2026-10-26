interface axi4stream_bus_ifc #(
    parameter unsigned AXI_DATA_WIDTH,
    parameter unsigned AXI_USER_WIDTH = 1,
    parameter unsigned AXI_ID_WIDTH   = 1,
    parameter unsigned AXI_DEST_WIDTH = 1
) (
    input logic ACLK,
    input logic ARESETN
);

    localparam unsigned TKEEP_WIDTH = AXI_DATA_WIDTH / 8;
    localparam unsigned TSTRB_WIDTH = AXI_DATA_WIDTH / 8;

    initial begin
        assert (AXI_DATA_WIDTH == 8 ||
                AXI_DATA_WIDTH == 16 ||
                AXI_DATA_WIDTH == 32 ||
                AXI_DATA_WIDTH == 64 ||
                AXI_DATA_WIDTH == 128 ||
                AXI_DATA_WIDTH == 256)
        else $error("Unsupported AXI data width");
    end

    logic [AXI_DATA_WIDTH-1 : 0] TDATA;
    logic [     TKEEP_WIDTH-1:0] TKEEP;
    logic                        TREADY;
    logic                        TVALID;
    logic                        TLAST;
    logic [     TSTRB_WIDTH-1:0] TSTRB;
    logic [  AXI_USER_WIDTH-1:0] TUSER;
    logic [    AXI_ID_WIDTH-1:0] TID;
    logic [  AXI_DEST_WIDTH-1:0] TDEST;

    modport MASTER(
        input ACLK,
        input ARESETN,

        output TDATA,
        output TKEEP,
        input TREADY,
        output TVALID,
        output TLAST,
        output TSTRB,
        output TUSER,
        output TID,
        output TDEST
    );

    modport SLAVE(
        input ACLK,
        input ARESETN,

        input TDATA,
        input TKEEP,
        output TREADY,
        input TVALID,
        input TLAST,
        input TSTRB,
        input TUSER,
        input TID,
        input TDEST
    );

endinterface
