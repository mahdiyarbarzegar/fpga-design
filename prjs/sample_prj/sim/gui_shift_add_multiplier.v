`timescale 1ns / 10ps

module gui_shift_add_multiplier;

  parameter MUL_SIZE = 4;

  reg                          clk;
  reg                          rst_n;
  reg                          start;
  wire                         ready;
  reg                          sign;
  reg signed  [  MUL_SIZE-1:0] a;
  reg signed  [  MUL_SIZE-1:0] b;
  wire signed [2*MUL_SIZE-1:0] y;

  shift_add_multiplier #(
    .MUL_WIDTH(MUL_SIZE)
  ) mul (
    .clk     (clk),
    .rst_n   (rst_n),
    .start   (start),
    .sign    (sign),
    .data_in1(a),
    .data_in2(b),
    .data_out(y),
    .ready   (ready)
  );

  initial begin
    clk = 1'b0;
    while (1) begin
      clk = ~clk;
      #5;
    end
  end

  initial begin
    start = 1'b0;
    rst_n = 1'b0;
    #10 rst_n = 1'b1;
    #10;

    sign  = 'b1;
    a     = -7;
    b     = -2;
    start = 1'b1;
    #10 start = 1'b0;
    @(posedge ready);
    #10;

    $stop;
  end
endmodule
