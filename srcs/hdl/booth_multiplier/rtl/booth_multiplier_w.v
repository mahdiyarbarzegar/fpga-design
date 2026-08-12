module booth_multiplier_w #(
  parameter DATA_WIDTH = 32
) (
  input                         clk,
  input                         rst_n,
  input                         start,
  input                         sign,
  input      [  DATA_WIDTH-1:0] a_i,
  input      [  DATA_WIDTH-1:0] b_i,
  output     [2*DATA_WIDTH-1:0] m_o,
  output reg                    ready
);

  booth_multiplier #(
    .MUL_WIDTH(DATA_WIDTH)
  ) b_mul (
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
