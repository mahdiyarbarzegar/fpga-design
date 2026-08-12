module carry_look_ahead_adder_w #(
  parameter BUS_WIDTH       = 32,
  parameter CLA_BLOCK_WIDTH = 4
) (
  input                  add_sub_b,
  input  [BUS_WIDTH-1:0] a_i,
  input  [BUS_WIDTH-1:0] b_i,
  output [BUS_WIDTH-1:0] y_o
);

  carry_look_ahead_adder #(
    .BUS_WIDTH      (BUS_WIDTH),
    .CLA_BLOCK_WIDTH(CLA_BLOCK_WIDTH)
  ) cla (

    .add_sub_b(add_sub_b),
    .in1      (a_i),
    .in2      (b_i),
    .out      (y_o)
  );

endmodule
