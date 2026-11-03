module ripple_carry_adder #(
  parameter BUS_WIDTH = 32
) (
  input                  add_sub_b,
  input                  sign,
  input  [BUS_WIDTH-1:0] in1,
  input  [BUS_WIDTH-1:0] in2,
  output [BUS_WIDTH-1:0] out,
  output                 z,
  output                 n,
  output                 c,
  output                 v
);

  wire [BUS_WIDTH:0] carry;
  assign carry[0] = add_sub_b;

  assign z        = ~(|out);
  assign n        = (sign) ? out[BUS_WIDTH-1] : 1'b0;
  assign c        = carry[BUS_WIDTH];
  assign v        = (sign) ? carry[BUS_WIDTH] ^ carry[BUS_WIDTH-1] : 1'b0;

  genvar i;
  generate
    for (i = 0; i < BUS_WIDTH; i = i + 1) begin : rca_slice
      full_adder fa (
        .cin (carry[i]),
        .in1 (in1[i]),
        .in2 (in2[i] ^ add_sub_b),
        .sum (out[i]),
        .cout(carry[i+1])
      );
    end
  endgenerate

endmodule
