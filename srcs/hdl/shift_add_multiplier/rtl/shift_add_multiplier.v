module shift_add_multiplier #(
  parameter MUL_WIDTH = 4
) (
  input                        clk,
  input                        rst_n,
  input                        start,
  input                        sign,
  input      [  MUL_WIDTH-1:0] data_in1,
  input      [  MUL_WIDTH-1:0] data_in2,
  output     [2*MUL_WIDTH-1:0] data_out,
  output reg                   ready
);

  reg  [  MUL_WIDTH-1:0] multiplicand;
  reg  [2*MUL_WIDTH-1:0] product;
  reg                    running;
  reg  [  MUL_WIDTH-1:0] counter;
  reg                    shift_right;
  wire                   in1_sign_bit;
  wire                   in2_sign_bit;
  wire                   product_sign_bit;
  wire [  MUL_WIDTH-1:0] in1;
  wire [  MUL_WIDTH-1:0] in2;
  wire [  MUL_WIDTH-1:0] sum_result;

  assign in1_sign_bit = data_in1[MUL_WIDTH-1];
  assign in2_sign_bit = data_in2[MUL_WIDTH-1];
  assign product_sign_bit = product[2*MUL_WIDTH-1];
  assign in1 = sign ? in1_sign_bit ? (~data_in1 + 1) : data_in1 : data_in1;
  assign in2 = sign ? in2_sign_bit ? (~data_in2 + 1) : data_in2 : data_in2;
  assign sum_result = multiplicand + product[2*MUL_WIDTH-1:MUL_WIDTH];
  assign data_out     = sign? (in1_sign_bit^in2_sign_bit^product_sign_bit)?(~product[2*MUL_WIDTH-1:0]+1):product[2*MUL_WIDTH-1:0]:product[2*MUL_WIDTH-1:0];

  always @(posedge clk) begin
    if (counter == MUL_WIDTH) begin
      ready   <= 'b1;
      running <= 'b0;
    end else begin
      if (running == 'b1) begin
        if (product[0] == 'b1 && shift_right == 'b0) begin
          product     <= {sum_result, product[MUL_WIDTH-1:0]};
          shift_right <= 'b1;
        end else begin
          shift_right <= 'b0;
          product     <= {1'b0, product[2*MUL_WIDTH-1:1]};
          counter     <= counter + 1;
        end
      end
    end

    if (running == 'b0 && start == 'b1) begin
      multiplicand <= in1;
      product      <= {{MUL_WIDTH{1'b0}}, in2};
      running      <= 'b1;
      ready        <= 'b0;
      counter      <= 'd0;
      shift_right  <= 'b0;
    end

    if (rst_n == 'b0) begin
      multiplicand <= {MUL_WIDTH{1'b0}};
      product      <= {2 * {MUL_WIDTH{1'b0}}};
      ready        <= 'b1;
      running      <= 'b0;
      counter      <= 'd0;
      shift_right  <= 'b0;
    end
  end

endmodule
