`include "pwm_gen.svh"

module gui_pwm_gen;

    localparam INTERFACE_TYPE = "SIMPLE";
    localparam TIMER_RESOLUTION = 32;
    localparam CHANNELS = 2;

    reg clk, rst_n, start, stop;
    reg [1:0] mode;
    reg [TIMER_RESOLUTION-1:0] clk_div, cnt_top;
    reg  [CHANNELS-1:0][TIMER_RESOLUTION-1:0] ccr;
    wire [CHANNELS-1:0]                       pwm;

    pwm_gen_w #(
        .INTERFACE_TYPE  (INTERFACE_TYPE),
        .TIMER_RESOLUTION(TIMER_RESOLUTION),
        .CHANNELS        (CHANNELS)
    ) pwmgen (
        .clk  (clk),
        .rst_n(rst_n),
        .start(start),
        .stop (stop),
        .mode (mode),
        .psc  (clk_div),
        .arr  (cnt_top),
        .ccr  (ccr),
        .oc   (pwm)
    );

    initial begin
        clk = 'b1;
        while (1) begin
            #5 clk = ~clk;
        end
    end

    integer i;
    initial begin
        rst_n = 0;
        start = 0;
        stop  = 0;

        #10 rst_n = 1;
        #5 start = 1;
        mode    = `CENTER_ALIGNED;
        clk_div = 1;
        cnt_top = 10;
        ccr[0]  = 2;
        ccr[1]  = 4;
        #20;
        start = 0;
        #100;

        for (i = 0; i < 10; i = i + 1) begin
            ccr[0] = i;
            ccr[1] = 10 - i;
            #400;
        end
        for (i = 10; i > 0; i = i - 1) begin
            ccr[0] = i;
            ccr[1] = 10 - i;
            #400;
        end

        $stop;
    end
endmodule
