module gui_demo_xil_fifo;

  reg clk, srst, wr_en, rd_en;
  wire full, almost_full, overflow, empty, almost_empty, underflow;
  wire [ 6:0] data_count;
  reg  [31:0] din;
  wire [31:0] dout;

  fifo_simple_xil inst (
    .clk         (clk),
    .srst        (srst),
    .din         (din),
    .wr_en       (wr_en),
    .rd_en       (rd_en),
    .dout        (dout),
    .full        (full),
    .almost_full (almost_full),
    .overflow    (overflow),
    .empty       (empty),
    .almost_empty(almost_empty),
    .underflow   (underflow),
    .data_count  (data_count)
  );

  initial begin
    clk = 'b1;
    while (1) begin
      #5 clk = ~clk;
    end
  end

  initial begin
    srst  = 'b1;
    wr_en = 'b0;
    rd_en = 'b0;
    #10 srst = 'b0;

    din   = 'hdeadbeef;
    wr_en = 1;
    #10 wr_en = 0;
    #10;

    din   = 'hdeadbabe;
    wr_en = 1;
    #10 wr_en = 0;
    #10;

    din   = 'hbaadbeef;
    wr_en = 1;
    #10 wr_en = 0;
    #10;

    rd_en = 1;
    #50;

    $stop;
  end

endmodule

