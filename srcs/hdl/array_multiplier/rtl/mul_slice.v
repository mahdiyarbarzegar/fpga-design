module mul_slice (
  input  ai,
  input  bi,
  input  pi,
  input  ci,
  output ao,
  output bo,
  output po,
  output co
);

  wire adder_input;

  assign adder_input = ai & bi;
  assign ao          = ai;
  assign bo          = bi;

  full_adder fa (
    .in1 (adder_input),
    .in2 (pi),
    .cin (ci),
    .sum (po),
    .cout(co)
  );

endmodule
