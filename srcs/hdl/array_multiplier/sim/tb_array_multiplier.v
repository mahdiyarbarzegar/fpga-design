module tb_array_multiplier;

  parameter MUL_SIZE = 4;

  reg                          sign;
  reg signed  [  MUL_SIZE-1:0] a;
  reg signed  [  MUL_SIZE-1:0] b;
  wire signed [2*MUL_SIZE-1:0] y;

  array_multiplier_w #(
    .DATA_WIDTH(MUL_SIZE)
  ) mul (
    .sign(sign),
    .a_i (a),
    .b_i (b),
    .m_o (y)
  );

  initial begin
    sign = 1'b0;
    a    = 6;
    b    = 9;
    #1;
    $display("a: %u, b: %u -> a*b: %d", $unsigned(a), $unsigned(b), y);
    if (y != ($unsigned(a) * $unsigned(b))) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    sign = 1'b1;
    a    = -4;
    b    = 3;
    #1;
    $display("a: %d, b: %d -> a*b: %d", a, b, y);
    if (y != (a * b)) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    sign = 1'b1;
    a    = -4;
    b    = -3;
    #1;
    $display("a: %d, b: %d -> a*b: %d", a, b, y);
    if (y != (a * b)) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    $finish;
  end

endmodule
