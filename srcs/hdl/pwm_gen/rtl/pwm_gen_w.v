`include "pwm_gen_reg_pkg.sv"

import pwm_gen_reg_pkg::*;

module pwm_gen_w #(
    parameter TIMER_RESOLUTION = 32,
    parameter CHANNELS         = 1
) (
    input clk,
    input rst_n,

    input                        start,
    input                        stop,
    input [                 1:0] mode,
    input [TIMER_RESOLUTION-1:0] psc,             // clk_cnt = clk / [pcs+1]
    input [TIMER_RESOLUTION-1:0] arr,
    input [TIMER_RESOLUTION-1:0] ccr  [CHANNELS],

    input  [    ADDR_WIDTH-1 : 0] s_axi_awaddr,
    input  [               2 : 0] s_axi_awprot,
    input                         s_axi_awvalid,
    output                        s_axi_awready,
    input  [    DATA_WIDTH-1 : 0] s_axi_wdata,
    input  [(DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
    input                         s_axi_wvalid,
    output                        s_axi_wready,
    output [               1 : 0] s_axi_bresp,
    output                        s_axi_bvalid,
    input                         s_axi_bready,
    input  [    ADDR_WIDTH-1 : 0] s_axi_araddr,
    input  [               2 : 0] s_axi_arprot,
    input                         s_axi_arvalid,
    output                        s_axi_arready,
    output [    DATA_WIDTH-1 : 0] s_axi_rdata,
    output [               1 : 0] s_axi_rresp,
    output                        s_axi_rvalid,
    input                         s_axi_rready,

    output [CHANNELS-1:0] oc
);

    pwm_gen #(
        .TIMER_RESOLUTION(TIMER_RESOLUTION),
        .CHANNELS        (CHANNELS)
    ) pwmgen (
        .clk  (clk),
        .rst_n(rst_n),

        .start(start),
        .stop (stop),
        .mode (mode),
        .psc  (psc),    // clk_cnt = clk / [pcs+1]
        .arr  (arr),
        .ccr  (ccr),
        .oc   (oc),

        .s_axi_awaddr (s_axi_awaddr),
        .s_axi_awprot (s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata  (s_axi_wdata),
        .s_axi_wstrb  (s_axi_wstrb),
        .s_axi_wvalid (s_axi_wvalid),
        .s_axi_wready (s_axi_wready),
        .s_axi_bresp  (s_axi_bresp),
        .s_axi_bvalid (s_axi_bvalid),
        .s_axi_bready (s_axi_bready),
        .s_axi_araddr (s_axi_araddr),
        .s_axi_arprot (s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rresp  (s_axi_rresp),
        .s_axi_rvalid (s_axi_rvalid),
        .s_axi_rready (s_axi_rready)
    );
endmodule
