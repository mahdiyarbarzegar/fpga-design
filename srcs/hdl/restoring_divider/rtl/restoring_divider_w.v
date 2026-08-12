module restoring_divider_w #(
  parameter BUS_WIDTH = 32
) (
  input                  clk,
  input                  rst_n,
  input                  start,
  input                  sign,
  input  [BUS_WIDTH-1:0] a_i,
  input  [BUS_WIDTH-1:0] b_i,
  output [BUS_WIDTH-1:0] q_o,
  output [BUS_WIDTH-1:0] r_o,
  output                 ready
);

  restoring_divider #(
    .DIV_WIDTH(BUS_WIDTH)
  ) div (
    .clk  (clk),
    .rst_n(rst_n),
    .start(start),
    .sign (sign),
    .in1  (a_i),
    .in2  (b_i),
    .q    (q_o),
    .r    (r_o),
    .ready(ready)
  );

endmodule
