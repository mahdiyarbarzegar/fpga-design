`include "pwm_gen_reg_pkg.sv"

import pwm_gen_reg_pkg::*;

module pwm_gen #(
    parameter TIMER_RESOLUTION = 32,
    parameter CHANNELS         = 1
) (
    input clk,
    input rst_n,

    input                         start,
    input                         stop,
    input  [                 1:0] mode,
    input  [TIMER_RESOLUTION-1:0] psc,              // clk_cnt = clk / [pcs+1]
    input  [TIMER_RESOLUTION-1:0] arr,
    input  [TIMER_RESOLUTION-1:0] ccr  [CHANNELS],
    output [        CHANNELS-1:0] oc,

    input  wire [    ADDR_WIDTH-1 : 0] s_axi_awaddr,
    input  wire [               2 : 0] s_axi_awprot,
    input  wire                        s_axi_awvalid,
    output wire                        s_axi_awready,
    input  wire [    DATA_WIDTH-1 : 0] s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
    input  wire                        s_axi_wvalid,
    output wire                        s_axi_wready,
    output wire [               1 : 0] s_axi_bresp,
    output wire                        s_axi_bvalid,
    input  wire                        s_axi_bready,
    input  wire [    ADDR_WIDTH-1 : 0] s_axi_araddr,
    input  wire [               2 : 0] s_axi_arprot,
    input  wire                        s_axi_arvalid,
    output wire                        s_axi_arready,
    output wire [    DATA_WIDTH-1 : 0] s_axi_rdata,
    output wire [               1 : 0] s_axi_rresp,
    output wire                        s_axi_rvalid,
    input  wire                        s_axi_rready
);

    axi4lite_bus_ifc #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) axi_bus_ifc (
        .ACLK   (clk),
        .ARESETN(rst_n)
    );

    axi4_reg_ifc #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_REGS  (NUM_REGS)
    ) reg_ifc_axi ();

    axi4lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .bus_ifc(axi_bus_ifc),
        .reg_ifc(reg_ifc_axi)
    );

    axi4_reg_ifc #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .CHANNELS  (NUM_REGS),
        .NUM_REGS  (NUM_REGS)
    ) reg_ifc_rtl ();

    axi4_reg_bank #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_REGS  (NUM_REGS),
        .REG_DESC_T(pwm_reg_desc_t),
        .REG_MAP   (PWM_GEN_REGMAP)
    ) reg_bank (
        .clk        (clk),
        .rst_n      (rst_n),
        .reg_ifc_axi(reg_ifc_axi),
        .reg_ifc_rtl(reg_ifc_rtl)
    );

    pwm_gen_regmap #(
        .TIMER_RESOLUTION(TIMER_RESOLUTION),
        .CHANNELS        (CHANNELS)
    ) reg_map (
        .clk        (clk),
        .rst_n      (rst_n),
        .reg_ifc_rtl(reg_ifc_rtl),
        .start,
        .stop,
        .mode,
        .psc,
        .arr,
        .ccr
    );

    pwm_gen_core #(
        .TIMER_RESOLUTION(TIMER_RESOLUTION),
        .CHANNELS        (CHANNELS)
    ) pwmgen_c (
        .clk  (clk),
        .rst_n(rst_n),
        .start(reg_map.start),
        .stop (reg_map.stop),
        .mode (reg_map.mode),
        .psc  (reg_map.psc),
        .arr  (reg_map.arr),
        .ccr  (reg_map.ccr),
        .oc   (oc)
    );

    assign axi_bus_ifc.AWADDR  = s_axi_awaddr;
    assign axi_bus_ifc.AWPROT  = s_axi_awprot;
    assign axi_bus_ifc.AWVALID = s_axi_awvalid;
    assign s_axi_awready       = axi_bus_ifc.AWREADY;

    assign axi_bus_ifc.WDATA   = s_axi_wdata;
    assign axi_bus_ifc.WSTRB   = s_axi_wstrb;
    assign axi_bus_ifc.WVALID  = s_axi_wvalid;
    assign s_axi_wready        = axi_bus_ifc.WREADY;

    assign s_axi_bresp         = axi_bus_ifc.BRESP;
    assign s_axi_bvalid        = axi_bus_ifc.BVALID;
    assign axi_bus_ifc.BREADY  = s_axi_bready;

    assign axi_bus_ifc.ARADDR  = s_axi_araddr;
    assign axi_bus_ifc.ARPROT  = s_axi_arprot;
    assign axi_bus_ifc.ARVALID = s_axi_arvalid;
    assign s_axi_arready       = axi_bus_ifc.ARREADY;

    assign s_axi_rdata         = axi_bus_ifc.RDATA;
    assign s_axi_rresp         = axi_bus_ifc.RRESP;
    assign s_axi_rvalid        = axi_bus_ifc.RVALID;
    assign axi_bus_ifc.RREADY  = s_axi_rready;

endmodule
