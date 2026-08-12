`timescale 1ns / 10ps

module cla_block #(
  parameter BUS_WIDTH = 4
) (
  input                  cin,
  input  [BUS_WIDTH-1:0] in1,
  input  [BUS_WIDTH-1:0] in2,
  output [BUS_WIDTH-1:0] s,
  output                 cout
);

  wire [BUS_WIDTH-1:0] p;
  wire [BUS_WIDTH-1:0] g;
  wire [  BUS_WIDTH:0] c;

  assign c[0] = cin;
  assign p    = in1 ^ in2;
  assign g    = in1 & in2;

  assign s    = c[BUS_WIDTH-1:0] ^ p;
  assign cout = c[BUS_WIDTH];

  carry_predictor #(
    .CARRY_WIDTH(BUS_WIDTH)
  ) cp (
    .cin (cin),
    .p   (p),
    .g   (g),
    .cout(c[BUS_WIDTH:1])
  );

endmodule
