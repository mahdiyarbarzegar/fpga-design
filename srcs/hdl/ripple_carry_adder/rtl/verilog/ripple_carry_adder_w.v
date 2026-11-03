module ripple_carry_adder_w #(
  parameter BUS_WIDTH = 32
) (
  input                  add_sub_b,
  input                  sign,
  input  [BUS_WIDTH-1:0] a_i,
  input  [BUS_WIDTH-1:0] b_i,
  output [BUS_WIDTH-1:0] y_o,
  output                 z,
  output                 n,
  output                 c,
  output                 v
);

  ripple_carry_adder #(
    .BUS_WIDTH(BUS_WIDTH)
  ) rca (
    .add_sub_b(add_sub_b),
    .sign     (sign),
    .in1      (a_i),
    .in2      (b_i),
    .out      (y_o),
    .z        (z),
    .n        (n),
    .c        (c),
    .v        (v)
  );

endmodule
