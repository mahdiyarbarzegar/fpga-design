module carry_look_ahead_adder #(
  parameter BUS_WIDTH       = 32,
  parameter CLA_BLOCK_WIDTH = 4
) (
  input                  add_sub_b,
  input  [BUS_WIDTH-1:0] in1,
  input  [BUS_WIDTH-1:0] in2,
  output [BUS_WIDTH-1:0] out
);

  localparam INTER_BLOCK_BUS_WIDTH = BUS_WIDTH / CLA_BLOCK_WIDTH;

  wire [INTER_BLOCK_BUS_WIDTH:0] c;
  assign c[0] = add_sub_b;

  genvar i;
  generate
    for (i = 0; i < INTER_BLOCK_BUS_WIDTH; i = i + 1) begin : cla_slice
      cla_block #(
        .BUS_WIDTH(CLA_BLOCK_WIDTH)
      ) cb (
        .cin (c[i]),
        .in1 (in1[(i+1)*CLA_BLOCK_WIDTH-1:i*CLA_BLOCK_WIDTH]),
        .in2 ((in2[(i+1)*CLA_BLOCK_WIDTH-1:i*CLA_BLOCK_WIDTH]) ^ {CLA_BLOCK_WIDTH{add_sub_b}}),
        .s   (out[(i+1)*CLA_BLOCK_WIDTH-1:i*CLA_BLOCK_WIDTH]),
        .cout(c[i+1])
      );
    end
  endgenerate

endmodule
