module tb_full_adder;

  reg a, b, cin;
  wire y, cout;

  full_adder fa (
    .in1 (a),
    .in2 (b),
    .cin (cin),
    .sum (y),
    .cout(cout)
  );

  initial begin
    a   = 1;
    b   = 0;
    cin = 1;
    #1;
    $display("in1: %b, in2: %b, cin: %b -> sum: %b, cout: %b", a, b, cin, y, cout);
    if ({cout, y} != 'd2) begin
      $display("wrong result!");
    end else begin
      $display("successfull result!");
    end

    $finish;
  end

endmodule
