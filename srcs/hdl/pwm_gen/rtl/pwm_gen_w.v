`include "pwm_gen.vh"

module pwm_gen_w #(
    parameter INTERFACE_TYPE   = "AXI4LITE_SLAVE",
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

    input  [    AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
    input  [                   2 : 0] s_axi_awprot,
    input                             s_axi_awvalid,
    output                            s_axi_awready,
    input  [    AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
    input  [(AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
    input                             s_axi_wvalid,
    output                            s_axi_wready,
    output [                   1 : 0] s_axi_bresp,
    output                            s_axi_bvalid,
    input                             s_axi_bready,
    input  [    AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
    input  [                   2 : 0] s_axi_arprot,
    input                             s_axi_arvalid,
    output                            s_axi_arready,
    output [    AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
    output [                   1 : 0] s_axi_rresp,
    output                            s_axi_rvalid,
    input                             s_axi_rready,

    output [CHANNELS-1:0] oc
);

    generate
        if (INTERFACE_TYPE == "AXI4LITE_SLAVE") begin : g_axi
            pwm_gen_bus_axi4lite #(
                .TIMER_RESOLUTION(TIMER_RESOLUTION),
                .CHANNELS        (CHANNELS)
            ) pwmgen (
                .clk  (clk),
                .rst_n(rst_n),

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
                .s_axi_rready (s_axi_rready),

                .oc(oc)
            );
        end else if (INTERFACE_TYPE == "SIMPLE") begin : g_simple
            pwm_gen_bus_simple #(
                .TIMER_RESOLUTION(TIMER_RESOLUTION),
                .CHANNELS        (CHANNELS)
            ) pwmgen (
                .clk  (clk),
                .rst_n(rst_n),

                .start(start),
                .stop (stop),
                .mode (mode),
                .psc  (psc),
                .arr  (arr),
                .ccr  (ccr),

                .oc(oc)
            );
        end
    endgenerate

endmodule
