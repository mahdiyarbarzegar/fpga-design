module full_adder (
  input  in1,
  input  in2,
  input  cin,
  output sum,
  output cout
);

  assign sum  = in1 ^ in2 ^ cin;
  assign cout = (in1 & in2) | (in1 & cin) | (in2 & cin);

endmodule
