`timescale 1ns / 10ps

module carry_predictor #(
  parameter CARRY_WIDTH = 4
) (
  input                    cin,
  input  [CARRY_WIDTH-1:0] p,
  input  [CARRY_WIDTH-1:0] g,
  output [CARRY_WIDTH-1:0] cout
);

  wire [CARRY_WIDTH:0] c;

  assign c[0] = cin;
  assign cout = c[CARRY_WIDTH:1];

  genvar i;
  generate
    for (i = 0; i < CARRY_WIDTH; i = i + 1) begin : cp_slice
      assign c[i+1] = (p[i] & c[i]) + g[i];
    end
  endgenerate

endmodule
