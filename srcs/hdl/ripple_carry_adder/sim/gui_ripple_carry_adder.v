module gui_ripple_carry_adder;

  parameter BUS_WIDTH = 32;

  reg                  add_sub_b;
  reg                  sign;
  reg  [BUS_WIDTH-1:0] a;
  reg  [BUS_WIDTH-1:0] b;
  wire [BUS_WIDTH-1:0] y;
  wire z, n, c, v;

  ripple_carry_adder_w #(
    .BUS_WIDTH(BUS_WIDTH)
  ) rca (
    .add_sub_b(add_sub_b),
    .sign     (sign),
    .a_i      (a),
    .b_i      (b),
    .y_o      (y),
    .z        (z),
    .n        (n),
    .c        (c),
    .v        (v)
  );

  initial begin
    add_sub_b = 'b1;
    sign      = 'b0;
    a         = 'd110;
    b         = 'd24;
    #10;

    add_sub_b = 'b1;
    sign      = 'b0;
    a         = 'd24;
    b         = 'd110;
    #10;

    $stop;
  end

endmodule
