module tb_ripple_carry_adder;

  parameter BUS_WIDTH = 8;

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
    add_sub_b = 'b0;
    sign      = 'b0;
    a         = 'd12;
    b         = 'd24;
    #1;
    $display("in1: %d, in2: %d -> in1 + in2: %d, z:%d-n:%d-c:%d-v:%d", a, b, y, z, n, c, v);
    if (y != 'd36) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    add_sub_b = 'b1;
    sign      = 'b0;
    a         = 'd110;
    b         = 'd24;
    #1;
    $display("in1: %d, in2: %d -> in1 - in2: %d, z:%d-n:%d-c:%d-v:%d", a, b, y, z, n, c, v);
    if (y != 'd86) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    add_sub_b = 'b0;
    sign      = 'b0;
    a         = 'd110;
    b         = 'd220;
    #1;
    $display("in1: %d, in2: %d -> in1 + in2: %d, z:%d-n:%d-c:%d-v:%d", a, b, y, z, n, c, v);
    if (c != 'b1) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    add_sub_b = 'b1;
    sign      = 'b0;
    a         = 'd110;
    b         = 'd220;
    #1;
    $display("in1: %d, in2: %d -> in1 - in2: %d, z:%d-n:%d-c:%d-v:%d", a, b, y, z, n, c, v);
    if (c != 'b0) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    $finish;
  end

endmodule
