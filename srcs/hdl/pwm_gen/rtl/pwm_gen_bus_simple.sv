module pwm_gen_bus_simple #(
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
    output [        CHANNELS-1:0] oc
);

    pwm_gen_core #(
        .TIMER_RESOLUTION(TIMER_RESOLUTION),
        .CHANNELS        (CHANNELS)
    ) pwmgen_c (
        .clk  (clk),
        .rst_n(rst_n),
        .start(start),
        .stop (stop),
        .mode (mode),
        .psc  (psc),
        .arr  (arr),
        .ccr  (ccr),
        .oc   (oc)
    );

endmodule
