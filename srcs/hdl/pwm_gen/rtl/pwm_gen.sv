`include "pwm_gen.vh"

module pwm_gen #(
  parameter TIMER_RESOLUTION = 32,
  parameter CHANNELS         = 1
) (
  input                                             clk,
  input                                             rst_n,
  input                                             start,
  input                                             stop,
  input                      [                 1:0] mode,
  input                      [TIMER_RESOLUTION-1:0] psc,    // clk_cnt = clk / [pcs+1]
  input                      [TIMER_RESOLUTION-1:0] arr,
  input        [CHANNELS-1:0][TIMER_RESOLUTION-1:0] ccr,
  output logic               [        CHANNELS-1:0] oc
);

  // states
  localparam logic [1:0] IDLE = 2'd0, LOADING = 2'd1, WORKING = 2'd2, STOPPED = 2'd3;

  logic [1:0] state, next_state;

  logic [TIMER_RESOLUTION-1:0]                       arr_shadow;
  logic [        CHANNELS-1:0][TIMER_RESOLUTION-1:0] ccr_shadow;
  logic [TIMER_RESOLUTION-1:0]                       clk_cnt;
  logic [TIMER_RESOLUTION-1:0]                       cnt;
  logic                                              cnt_inc_dec_b;

  ////////////////////////////////////////////////////////////////////
  /////////////////////////// Data-Path //////////////////////////////
  ////////////////////////////////////////////////////////////////////

  always_comb begin
    case (state)
      IDLE: begin
        cnt_inc_dec_b <= 1;
      end
      WORKING: begin
        case (mode)
          `CENTER_ALIGNED: begin
            if (cnt == arr_shadow - 1) cnt_inc_dec_b = 0;
            if (cnt == 0) cnt_inc_dec_b = 1;
          end
        endcase
      end
    endcase
  end

  always_ff @(posedge clk) begin
    case (state)
      IDLE: begin
        clk_cnt    <= 0;
        cnt        <= 0;
        arr_shadow <= 0;
      end
      LOADING: begin
        arr_shadow <= arr;
      end
      WORKING: begin
        if (cnt == 0) arr_shadow <= arr;

        clk_cnt <= clk_cnt + 1;
        if (clk_cnt >= psc) begin
          clk_cnt <= 0;

          if (cnt_inc_dec_b) begin
            cnt <= cnt + 1;
            if (cnt >= arr_shadow - 1) cnt <= 0;
          end else begin
            cnt <= cnt - 1;
          end
        end
      end
    endcase
  end

  genvar i;
  generate
    for (i = 0; i < CHANNELS; i = i + 1) begin : CH
      always_comb begin
        case (state)
          IDLE: oc[i] = 0;
          WORKING: begin
            case (mode)
              `RIGHT_ALIGNED:  oc[i] = cnt >= ccr_shadow[i];
              `LEFT_ALIGNED:   oc[i] = cnt < ccr_shadow[i];
              `CENTER_ALIGNED: oc[i] = cnt < ccr_shadow[i];
            endcase
          end
        endcase
      end

      always_ff @(posedge clk) begin
        case (state)
          IDLE:    ccr_shadow[i] <= 0;
          LOADING: ccr_shadow[i] <= ccr[i];
          WORKING: if (cnt == 0) ccr_shadow[i] <= ccr[i];
        endcase
      end
    end
  endgenerate

  ////////////////////////////////////////////////////////////////////
  /////////////////////////// Controller /////////////////////////////
  ////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk) begin
    state <= next_state;
  end

  always_comb begin
    case (state)
      IDLE:    if (start) next_state = LOADING;
      LOADING: if (start == 0) next_state = WORKING;
      WORKING: next_state = WORKING;
      STOPPED: next_state = STOPPED;
    endcase

    if (rst_n == 0) next_state = IDLE;
    if (stop) next_state = STOPPED;
  end

endmodule
