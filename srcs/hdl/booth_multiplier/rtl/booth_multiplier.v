module booth_multiplier #(
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

  reg  [    MUL_WIDTH:0] multiplicand;
  reg  [2*MUL_WIDTH+1:0] product;
  reg                    running;
  reg  [  MUL_WIDTH-1:0] counter;
  reg                    shift_right;
  wire [    MUL_WIDTH:0] in1;
  wire [    MUL_WIDTH:0] sum_result;
  wire [    MUL_WIDTH:0] sub_result;
  wire [            1:0] booth_state;

  assign in1         = sign ? {data_in1[MUL_WIDTH-1], data_in1} : {1'b0, data_in1};
  assign sum_result  = product[2*MUL_WIDTH+1:MUL_WIDTH+1] + multiplicand;
  assign sub_result  = product[2*MUL_WIDTH+1:MUL_WIDTH+1] - multiplicand;
  assign data_out    = product[2*MUL_WIDTH:1];
  assign booth_state = product[1:0];

  always @(posedge clk) begin
    if (counter == MUL_WIDTH) begin
      ready   <= 'b1;
      running <= 'b0;
    end else begin
      if (running == 'b1) begin
        if (shift_right == 'b0 && booth_state == 2'b01) begin
          product     <= {sum_result, product[MUL_WIDTH:0]};
          shift_right <= 'b1;
        end else if (shift_right == 'b0 && booth_state == 2'b10) begin
          product     <= {sub_result, product[MUL_WIDTH:0]};
          shift_right <= 'b1;
        end else begin
          shift_right <= 'b0;
          product     <= {product[2*MUL_WIDTH+1], product[2*MUL_WIDTH+1:1]};
          counter     <= counter + 1;
        end
      end
    end

    if (running == 'b0 && start == 'b1) begin
      multiplicand <= in1;
      product      <= {{(MUL_WIDTH + 1) {1'b0}}, data_in2, 1'b0};
      running      <= 'b1;
      ready        <= 'b0;
      counter      <= 'd0;
      shift_right  <= 'b0;
    end

    if (rst_n == 'b0) begin
      multiplicand <= {(MUL_WIDTH + 1) {1'b0}};
      product      <= {((2 * MUL_WIDTH) + 1) {1'b0}};
      ready        <= 'b1;
      running      <= 'b0;
      counter      <= 'd0;
      shift_right  <= 'b0;
    end
  end
endmodule
