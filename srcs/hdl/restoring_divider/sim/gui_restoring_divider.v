module gui_restoring_divider;

  parameter BUS_WIDTH = 8;

  reg clk;
  reg rst_n;
  reg start;
  reg sign;
  reg signed [BUS_WIDTH-1:0] a, b;
  wire signed [BUS_WIDTH-1:0] q, r;
  wire ready;

  restoring_divider_w #(
    .BUS_WIDTH(BUS_WIDTH)
  ) div (
    .clk  (clk),
    .rst_n(rst_n),
    .start(start),
    .sign (sign),
    .a_i  (a),
    .b_i  (b),
    .q_o  (q),
    .r_o  (r),
    .ready(ready)
  );

  initial begin
    clk = 'b0;
    while (1) begin
      #5 clk = ~clk;
    end
  end

  initial begin
    start = 'b0;
    rst_n = 'b0;
    #10 rst_n = 'b1;
    #10;

    sign = 'b1;
    a    = 'd26;
    b    = 'd7;
    #10 start = 'b1;
    #10 start = 'b0;
    @(posedge ready);
    #20;

    sign = 'b1;
    a    = -26;
    b    = 7;
    #10 start = 'b1;
    #10 start = 'b0;
    @(posedge ready);
    $display("a:%d, b:%d, a / b:%d, a %% b:%d", a, b, q, r);
    #20;

    sign = 'b1;
    a    = -26;
    b    = -7;
    #10 start = 'b1;
    #10 start = 'b0;
    @(posedge ready);
    $display("a:%d, b:%d, a / b:%u, a %% b:%d", a, b, $unsigned(q), r);
    #20;

    sign = 'b1;
    a    = -7;
    b    = 26;
    #10 start = 'b1;
    #10 start = 'b0;
    @(posedge ready);
    $display("a:%d, b:%d, a / b:%d, a %% b:%d", a, b, q, r);
    #20;

    $stop;
  end

endmodule
