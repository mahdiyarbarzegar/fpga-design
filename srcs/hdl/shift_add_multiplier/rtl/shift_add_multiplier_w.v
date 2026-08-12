module shift_add_multiplier_w #(
  parameter BUS_WIDTH = 4
) (
  input                    clk,
  input                    rst_n,
  input                    start,
  input                    sign,
  input  [  BUS_WIDTH-1:0] a_i,
  input  [  BUS_WIDTH-1:0] b_i,
  output [2*BUS_WIDTH-1:0] m_o,
  output                   ready
);

  shift_add_multiplier #(
    .MUL_WIDTH(BUS_WIDTH)
  ) samul (
    .clk     (clk),
    .rst_n   (rst_n),
    .start   (start),
    .sign    (sign),
    .data_in1(a_i),
    .data_in2(b_i),
    .data_out(m_o),
    .ready   (ready)
  );

endmodule
