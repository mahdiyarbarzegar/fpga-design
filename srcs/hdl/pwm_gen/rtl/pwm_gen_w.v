module pwm_gen_w #(
  parameter TIMER_RESOLUTION = 32,
  parameter CHANNELS         = 1
) (
  input                                    clk,
  input                                    rst_n,
  input                                    start,
  input                                    stop,
  input  [                            1:0] mode,
  input  [           TIMER_RESOLUTION-1:0] psc,    // clk_cnt = clk / [pcs+1]
  input  [           TIMER_RESOLUTION-1:0] arr,
  input  [CHANNELS * TIMER_RESOLUTION-1:0] ccr,
  output [                   CHANNELS-1:0] oc
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
    .psc  (psc),
    .arr  (arr),
    .ccr  (ccr),
    .oc   (oc)
  );

endmodule
