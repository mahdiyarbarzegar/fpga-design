module tb_restoring_divider;

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
            clk = ~clk;
            #5;
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
        @(negedge clk);
        start = 'b1;
        #10 @(negedge clk);
        start = 'b0;
        @(posedge ready);
        #10;
        $display("a:%d, b:%d, a / b:%d, a %% b:%d", a, b, q, r);
        if (q == a / b && r == a % b) begin
            $display("successfull result!");
        end else begin
            $display("wrong result!");
        end

        sign = 'b1;
        a    = -26;
        b    = 7;
        @(negedge clk);
        start = 'b1;
        #10 @(negedge clk);
        start = 'b0;
        @(posedge ready);
        #10;
        $display("a:%d, b:%d, a / b:%d, a %% b:%d", a, b, q, $signed(r));
        if (q == a / b && r == a % b) begin
            $display("successfull result!");
        end else begin
            $display("wrong result!");
        end

        sign = 'b1;
        a    = -26;
        b    = -7;
        @(negedge clk);
        start = 'b1;
        #10 @(negedge clk);
        start = 'b0;
        @(posedge ready);
        #10;
        $display("a:%d, b:%d, a / b:%d, a %% b:%d", a, b, $unsigned(q), $signed(r));
        if (q == a / b && r == a % b) begin
            $display("successfull result!");
        end else begin
            $display("wrong result!");
        end

        sign = 'b1;
        a    = -7;
        b    = 26;
        @(negedge clk);
        start = 'b1;
        #10 @(negedge clk);
        start = 'b0;
        @(posedge ready);
        #10;
        $display("a:%d, b:%d, a / b:%d, a %% b:%d", a, b, q, $signed(r));
        if (q == a / b && r == a % b) begin
            $display("successfull result!");
        end else begin
            $display("wrong result!");
        end

        sign = 'b0;
        a    = 240;
        b    = 26;
        @(negedge clk);
        start = 'b1;
        #10 @(negedge clk);
        start = 'b0;
        @(posedge ready);
        #10;
        $display("a:%d, b:%d, a / b:%d, a %% b:%d", $unsigned(a), $unsigned(b), $unsigned(q),
                 $unsigned(r));
        if (q == $unsigned(a) / $unsigned(b) && r == $unsigned(a) % $unsigned(b)) begin
            $display("successfull result!");
        end else begin
            $display("wrong result!");
        end

        sign = 'b0;
        a    = 26;
        b    = 240;
        @(negedge clk);
        start = 'b1;
        #10 @(negedge clk);
        start = 'b0;
        @(posedge ready);
        #10;
        $display("a:%d, b:%d, a / b:%d, a %% b:%d", $unsigned(a), $unsigned(b), $unsigned(q),
                 $unsigned(r));
        if (q == $unsigned(a) / $unsigned(b) && r == $unsigned(a) % $unsigned(b)) begin
            $display("successfull result!");
        end else begin
            $display("wrong result!");
        end

        $finish;
    end

endmodule
