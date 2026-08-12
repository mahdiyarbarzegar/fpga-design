`timescale 1ns / 10ps

module tb_carry_look_ahead_adder;

  parameter ADDER_SIZE = 32;
  parameter CLA_BLOCK_SIZE = 4;

  reg                   add_sub_b;
  reg  [ADDER_SIZE-1:0] a;
  reg  [ADDER_SIZE-1:0] b;
  wire [ADDER_SIZE-1:0] sum;

  carry_look_ahead_adder #(
    .BUS_WIDTH      (ADDER_SIZE),
    .CLA_BLOCK_WIDTH(CLA_BLOCK_SIZE)
  ) cla (
    .add_sub_b(add_sub_b),
    .in1      (a),
    .in2      (b),
    .out      (sum)
  );

  initial begin
    add_sub_b = 'b0;
    a         = 'd12;
    b         = 'd16;
    #1;
    $display("in1: %d, in2: %d -> in1 + in2: %d", a, b, sum);
    if (sum != 'd28) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    add_sub_b = 'b1;
    a         = 'd456;
    b         = 'd16;
    #1;
    $display("in1: %d, in2: %d -> in1 - in2: %d", a, b, sum);
    if (sum != 'd440) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    $finish;
  end

endmodule
