module array_multiplier #(
  parameter MUL_SIZE = 4
) (
  input                   sign,
  input  [  MUL_SIZE-1:0] a_in,
  input  [  MUL_SIZE-1:0] b_in,
  output [2*MUL_SIZE-1:0] m_out
);

  parameter MID_SIZE = 2 * MUL_SIZE;

  wire [  MID_SIZE-1:0] a[MID_SIZE:0];
  wire [  MID_SIZE-1:0] b[MID_SIZE:0];
  wire [  MID_SIZE-1:0] c[MID_SIZE:0];
  wire [2*MID_SIZE-1:0] p[MID_SIZE:0];

  assign a[0] = sign ? {{MUL_SIZE{a_in[MUL_SIZE-1]}}, a_in} : {{MUL_SIZE{1'b0}}, a_in};
  assign b[0] = sign ? {{MUL_SIZE{b_in[MUL_SIZE-1]}}, b_in} : {{MUL_SIZE{1'b0}}, b_in};
  assign c[0] = {MID_SIZE{1'b0}};
  assign p[0] = {(2 * MID_SIZE - 1) {1'b0}};

  genvar i, j;
  generate
    for (i = 0; i < MID_SIZE; i = i + 1) begin : mul_row
      for (j = 0; j < MID_SIZE; j = j + 1) begin : mul_col
        mul_slice mul (
          .ai(a[j][i]),
          .bi(b[i][j]),
          .pi(p[i][i+j]),
          .ci(c[j][i]),
          .ao(a[j+1][i]),
          .bo(b[i+1][j]),
          .po(p[i+1][i+j]),
          .co(c[j+1][i])
        );
      end

      assign p[i+1][MID_SIZE+i] = c[MID_SIZE][i];
      assign m_out[i]           = p[i+1][i];
    end
  endgenerate
endmodule
