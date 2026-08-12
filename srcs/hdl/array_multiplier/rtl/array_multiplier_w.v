module array_multiplier_w #(
  parameter DATA_WIDTH = 32
) (
  input                     sign,
  input  [  DATA_WIDTH-1:0] a_i,
  input  [  DATA_WIDTH-1:0] b_i,
  output [2*DATA_WIDTH-1:0] m_o
);

  array_multiplier #(
    .MUL_SIZE(DATA_WIDTH)
  ) mul (
    .sign (sign),
    .a_in (a),
    .b_in (b),
    .m_out(y)
  );

endmodule
